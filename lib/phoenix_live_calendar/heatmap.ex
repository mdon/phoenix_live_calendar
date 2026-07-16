defmodule PhoenixLiveCalendar.Heatmap do
  @moduledoc """
  Maps per-day numeric data onto heatmap-style `PhoenixLiveCalendar.DayMarker`s —
  the GitHub-contributions look for the month and year views.

  Give it a map (or list of pairs) of `Date => value` and it returns one
  marker per active day, carrying an intensity class from the palette as the
  marker `color` (which the month grid renders as the whole cell background
  and the year view as the mini-cell tint):

      markers = Heatmap.markers(%{~D[2026-04-01] => 12, ~D[2026-04-02] => 95})

      <.live_component
        module={PhoenixLiveCalendar.CalendarComponent}
        id="history"
        day_markers={markers}
      />

  ## Options

  - `:palette` — intensity classes, low → high (default: 5 `bg-success`
    opacity steps). Classes must be COMPLETE Tailwind class names the host
    app already uses or safelists — interpolated names get purged
  - `:scale` — `:linear` (bucket by `value / max`, default) or `:quantile`
    (bucket by rank, so outliers don't wash out the rest)
  - `:max` — explicit ceiling for the linear scale (default: the data's max)
  - `:label` — `value -> String.t()` for the marker label (used by tooltips
    and, when `show_label: true`, the corner chip). Pass `nil` for no label
  - `:show_label` — render the corner label chip (default `false`; heatmap
    days usually want just the tint)
  - `:id_prefix` — marker id prefix (default `"heatmap"`)

  Days with a zero, negative, or non-numeric value get no marker — no
  activity means no tint. The raw value is kept in `marker.extra.value`.
  """

  alias PhoenixLiveCalendar.DayMarker

  @default_palette [
    "bg-success/20",
    "bg-success/40",
    "bg-success/60",
    "bg-success/80",
    "bg-success"
  ]

  @doc "The default 5-step intensity palette."
  @spec default_palette() :: [String.t()]
  def default_palette, do: @default_palette

  @doc """
  Builds one heatmap `DayMarker` per active day from `Date => value` data.

  Accepts a map or an enumerable of `{Date, value}` pairs. See the moduledoc
  for options.
  """
  @spec markers(%{optional(Date.t()) => number()} | Enumerable.t(), keyword()) :: [DayMarker.t()]
  def markers(data, opts \\ []) do
    palette = Keyword.get(opts, :palette, @default_palette)

    if palette == [] do
      raise ArgumentError, ":palette must not be empty"
    end

    label = Keyword.get(opts, :label, &default_label/1)
    show_label = Keyword.get(opts, :show_label, false)
    id_prefix = Keyword.get(opts, :id_prefix, "heatmap")

    pairs =
      data
      |> Enum.filter(fn
        {%Date{}, value} -> is_number(value) and value > 0
        _other -> false
      end)
      |> Enum.sort_by(fn {date, _} -> date end, Date)

    bucket = bucket_fn(pairs, length(palette), Keyword.get(opts, :scale, :linear), opts)

    Enum.map(pairs, fn {date, value} ->
      %DayMarker{
        id: "#{id_prefix}-#{Date.to_iso8601(date)}",
        label: label && label.(value),
        start_date: date,
        type: :custom,
        color: Enum.at(palette, bucket.(value)),
        show_label: show_label,
        extra: %{value: value}
      }
    end)
  end

  defp default_label(value), do: to_string(value)

  defp bucket_fn([], _n, _scale, _opts), do: fn _ -> 0 end

  defp bucket_fn(pairs, n, :linear, opts) do
    max_value =
      case Keyword.get(opts, :max) do
        m when is_number(m) and m > 0 -> m
        _ -> pairs |> Enum.map(&elem(&1, 1)) |> Enum.max()
      end

    fn value ->
      (value / max_value * n)
      |> Float.ceil()
      |> trunc()
      |> Kernel.-(1)
      |> max(0)
      |> min(n - 1)
    end
  end

  defp bucket_fn(pairs, n, :quantile, _opts) do
    sorted = pairs |> Enum.map(&elem(&1, 1)) |> Enum.sort()
    count = length(sorted)

    fn value ->
      rank = Enum.count(sorted, &(&1 <= value))
      min(div((rank - 1) * n, count), n - 1)
    end
  end
end
