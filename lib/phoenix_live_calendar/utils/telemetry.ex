defmodule PhoenixLiveCalendar.Utils.Telemetry do
  @moduledoc """
  Performance measurement and telemetry for PhoenixLiveCalendar.

  Emits `:telemetry` events so consumers can attach their own handlers
  (LiveDashboard, Grafana, etc.) and logs warnings when operations exceed
  configurable thresholds.

  ## Telemetry events

  All events are prefixed with `[:phoenix_live_calendar]`:

  | Event | Measurements | Metadata |
  |-------|-------------|----------|
  | `[:phoenix_live_calendar, :measure, :start]` | `%{system_time: integer}` | `%{label: atom}` ++ custom |
  | `[:phoenix_live_calendar, :measure, :stop]` | `%{duration: integer}` | `%{label: atom}` ++ custom |
  | `[:phoenix_live_calendar, :measure, :exception]` | `%{duration: integer}` | `%{label: atom, kind: atom, reason: term, stacktrace: list}` |
  | `[:phoenix_live_calendar, :ingress]` | `%{event_count: integer, estimated_bytes: integer}` | `%{view: atom}` |

  ## Configuration

      config :phoenix_live_calendar,
        perf_warnings: true,
        perf_thresholds: %{
          group_events: 10,
          slot_layout: 5,
          filter: 5,
          overlap_layout: 5
        }

  Set `perf_warnings: false` to silence all Logger warnings. Override individual
  thresholds via the `perf_thresholds` map.
  """

  require Logger

  @default_thresholds %{
    group_events: 10,
    slot_layout: 5,
    filter: 5,
    overlap_layout: 5,
    ingress: 0
  }

  # Ingress: always measure once on data arrival, regardless of size.
  # This catches "few items but huge payloads" that count-based checks miss.
  @ingress_event_warn_count 500
  @ingress_bytes_warn 512_000

  @doc """
  Measures the execution time of `fun`, emits telemetry events, and logs
  a warning if the duration exceeds the configured threshold for `label`.

  Returns the result of `fun`.

  ## Examples

      Telemetry.measure(:group_events, %{events: 200, dates: 42}, fn ->
        DateHelpers.group_events_by_date(events, dates)
      end)
  """
  @spec measure(atom(), map(), (-> result)) :: result when result: var
  def measure(label, metadata \\ %{}, fun) when is_atom(label) and is_function(fun, 0) do
    full_meta = Map.put(metadata, :label, label)

    :telemetry.span(
      [:phoenix_live_calendar, :measure],
      full_meta,
      fn ->
        result = fun.()
        {result, full_meta}
      end
    )
  after
    :ok
  end

  @doc """
  Measures and also checks duration against threshold, logging a warning
  if exceeded. Use this instead of `measure/3` for hot paths where you
  want automatic threshold warnings.

  Returns the result of `fun`.
  """
  @spec measure_and_warn(atom(), map(), (-> result)) :: result when result: var
  def measure_and_warn(label, metadata \\ %{}, fun) when is_atom(label) and is_function(fun, 0) do
    {microseconds, result} = :timer.tc(fun)
    ms = microseconds / 1000

    full_meta = Map.merge(metadata, %{label: label, duration_ms: ms})

    :telemetry.execute(
      [:phoenix_live_calendar, :measure, :stop],
      %{duration: microseconds},
      full_meta
    )

    maybe_warn(label, ms, metadata)

    result
  end

  @doc """
  Profiles an incoming event list at ingress time. Always runs exactly once
  per data update, regardless of dataset size.

  Emits a `[:phoenix_live_calendar, :ingress]` telemetry event and logs warnings
  for large datasets or high memory usage.

  Returns `{event_count, estimated_bytes}` for the caller to use in
  downstream decisions (e.g. whether to measure hot paths).
  """
  @spec profile_ingress([struct()], atom()) :: {non_neg_integer(), non_neg_integer()}
  def profile_ingress(events, view \\ :unknown) when is_list(events) do
    count = length(events)
    estimated_bytes = estimate_memory(events)

    :telemetry.execute(
      [:phoenix_live_calendar, :ingress],
      %{event_count: count, estimated_bytes: estimated_bytes},
      %{view: view}
    )

    if warnings_enabled?() do
      cond do
        count > @ingress_event_warn_count and estimated_bytes > @ingress_bytes_warn ->
          Logger.warning(
            "[PhoenixLiveCalendar] Large dataset: #{count} events, ~#{format_bytes(estimated_bytes)}. " <>
              "Consider using on_date_range_change to load only the visible range."
          )

        count > @ingress_event_warn_count ->
          Logger.warning(
            "[PhoenixLiveCalendar] #{count} events passed. " <>
              "Consider using on_date_range_change to load only the visible range."
          )

        estimated_bytes > @ingress_bytes_warn ->
          Logger.warning(
            "[PhoenixLiveCalendar] Event data is ~#{format_bytes(estimated_bytes)} (#{count} events). " <>
              "Large extra/description fields may impact render performance. " <>
              "Consider trimming unused fields before passing to the calendar."
          )

        true ->
          :ok
      end
    end

    {count, estimated_bytes}
  end

  @doc """
  Returns whether measurement should run for hot paths given the dataset size.
  Small datasets skip measurement to avoid overhead.
  """
  @spec should_measure?(non_neg_integer()) :: boolean()
  def should_measure?(event_count) do
    event_count > 100 or always_measure?()
  end

  @doc """
  Returns the configured threshold in milliseconds for a given label.
  """
  @spec threshold(atom()) :: number()
  def threshold(label) do
    custom = Application.get_env(:phoenix_live_calendar, :perf_thresholds, %{})
    Map.get(custom, label) || Map.get(@default_thresholds, label, 10)
  end

  @doc """
  Returns whether perf warnings are enabled.
  """
  @spec warnings_enabled?() :: boolean()
  def warnings_enabled? do
    Application.get_env(:phoenix_live_calendar, :perf_warnings, true)
  end

  # -- Private --

  defp maybe_warn(label, ms, metadata) do
    if warnings_enabled?() and ms > threshold(label) do
      meta_str =
        metadata
        |> Map.drop([:label, :duration_ms])
        |> inspect()

      Logger.warning(
        "[PhoenixLiveCalendar] #{label} took #{Float.round(ms, 1)}ms (threshold: #{threshold(label)}ms). " <>
          "Context: #{meta_str}"
      )
    end
  end

  defp always_measure? do
    Application.get_env(:phoenix_live_calendar, :perf_always_measure, false)
  end

  defp estimate_memory(events) do
    # Sample-based estimation: measure a sample and extrapolate.
    # :erts_debug.size/1 returns word count — multiply by word size for bytes.
    count = length(events)

    cond do
      count == 0 ->
        0

      count <= 20 ->
        :erts_debug.size(events) * :erlang.system_info(:wordsize)

      true ->
        # Sample up to 20 events and extrapolate
        sample = Enum.take(events, 20)
        sample_bytes = :erts_debug.size(sample) * :erlang.system_info(:wordsize)
        sample_avg = sample_bytes / length(sample)
        round(sample_avg * count)
    end
  end

  defp format_bytes(bytes) when bytes < 1024, do: "#{bytes}B"
  defp format_bytes(bytes) when bytes < 1_048_576, do: "#{Float.round(bytes / 1024, 1)}KB"
  defp format_bytes(bytes), do: "#{Float.round(bytes / 1_048_576, 1)}MB"
end
