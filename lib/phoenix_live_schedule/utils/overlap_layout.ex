defmodule PhoenixLiveSchedule.Utils.OverlapLayout do
  @moduledoc """
  Computes side-by-side positioning for overlapping events in a time grid.

  When multiple events occupy the same time range, they need to be rendered
  side by side rather than stacked on top of each other. This module computes
  the column index and total column count for each event.

  ## Algorithm

  Uses a greedy column assignment:
  1. Sort events by start time, then by duration (longest first)
  2. For each event, find the first column where it doesn't overlap with
     any already-placed event
  3. After all events are placed, compute the maximum column count for
     each group of overlapping events

  ## Output

  Returns a map of `%{event_id => %{column: integer, total_columns: integer}}`
  which the view uses to compute `left` and `width` CSS positioning.
  """

  alias PhoenixLiveSchedule.Event
  alias PhoenixLiveSchedule.Utils.Telemetry

  @type layout_info :: %{column: non_neg_integer(), total_columns: pos_integer()}
  @type layout_map :: %{term() => layout_info()}

  @doc """
  Computes the overlap layout for a list of timed events on a single day.

  Returns a map from event ID to `%{column: N, total_columns: M}`.
  Events that don't overlap get `%{column: 0, total_columns: 1}`.

  ## Examples

      events = [
        %Event{id: "a", start: ~U[2026-04-01 09:00:00Z], end: ~U[2026-04-01 10:00:00Z]},
        %Event{id: "b", start: ~U[2026-04-01 09:30:00Z], end: ~U[2026-04-01 10:30:00Z]},
        %Event{id: "c", start: ~U[2026-04-01 11:00:00Z], end: ~U[2026-04-01 12:00:00Z]}
      ]

      layout = OverlapLayout.compute(events)
      # => %{
      #   "a" => %{column: 0, total_columns: 2},
      #   "b" => %{column: 1, total_columns: 2},
      #   "c" => %{column: 0, total_columns: 1}
      # }
  """
  @spec compute([Event.t()]) :: layout_map()
  def compute([]), do: %{}
  def compute([event]), do: %{event.id => %{column: 0, total_columns: 1}}

  def compute(events) do
    do_compute = fn ->
      timed =
        events
        |> Enum.reject(&Event.all_day?/1)
        |> Enum.sort_by(fn e -> {e.start, -Event.duration_seconds(e)} end)

      if timed == [] do
        %{}
      else
        columns = assign_columns(timed)
        groups = compute_overlap_groups(timed)
        build_layout_map(groups, columns)
      end
    end

    if Telemetry.should_measure?(length(events)) do
      Telemetry.measure_and_warn(:overlap_layout, %{events: length(events)}, do_compute)
    else
      do_compute.()
    end
  end

  @doc """
  Returns CSS style string for an event's horizontal position within its column.

  ## Examples

      style = OverlapLayout.position_style(%{column: 1, total_columns: 3})
      # => "left: 33.33%; width: 33.33%"
  """
  @spec position_style(layout_info()) :: String.t()
  def position_style(%{column: col, total_columns: total}) when total > 0 do
    width = 100.0 / total
    left = col * width
    "left: #{Float.round(left, 2)}%; width: #{Float.round(width, 2)}%"
  end

  def position_style(_), do: "left: 0%; width: 100%"

  # -- Private --

  defp assign_columns(timed) do
    {columns, _} =
      Enum.reduce(timed, {%{}, []}, fn event, {col_map, placed} ->
        col = find_free_column(event, placed)
        new_placed = [{event, col} | placed]
        {Map.put(col_map, event.id, col), new_placed}
      end)

    columns
  end

  defp build_layout_map(groups, columns) do
    Enum.reduce(groups, %{}, fn group, acc ->
      total = group |> Enum.map(&Map.get(columns, &1.id, 0)) |> Enum.max() |> Kernel.+(1)

      Enum.reduce(group, acc, fn event, inner_acc ->
        Map.put(inner_acc, event.id, %{
          column: Map.get(columns, event.id, 0),
          total_columns: total
        })
      end)
    end)
  end

  defp find_free_column(event, placed) do
    # Find the lowest column index where this event doesn't conflict
    conflicting_columns =
      placed
      |> Enum.filter(fn {placed_event, _col} -> events_overlap?(event, placed_event) end)
      |> Enum.map(fn {_event, col} -> col end)
      |> MapSet.new()

    Stream.iterate(0, &(&1 + 1))
    |> Enum.find(&(not MapSet.member?(conflicting_columns, &1)))
  end

  defp compute_overlap_groups(events) do
    # Build groups of mutually overlapping events
    Enum.reduce(events, [], fn event, groups ->
      # Find all groups this event overlaps with
      {overlapping, non_overlapping} =
        Enum.split_with(groups, fn group ->
          Enum.any?(group, &events_overlap?(event, &1))
        end)

      # Merge all overlapping groups with this event
      merged = [event | Enum.flat_map(overlapping, & &1)]
      [merged | non_overlapping]
    end)
  end

  defp events_overlap?(a, b) do
    a_end = Event.effective_end(a)
    b_end = Event.effective_end(b)

    compare(a.start, b_end) == :lt and compare(a_end, b.start) == :gt
  end

  defp compare(%DateTime{} = a, %DateTime{} = b), do: DateTime.compare(a, b)
  defp compare(%NaiveDateTime{} = a, %NaiveDateTime{} = b), do: NaiveDateTime.compare(a, b)
  defp compare(a, b), do: Date.compare(to_date(a), to_date(b))

  defp to_date(%Date{} = d), do: d
  defp to_date(%DateTime{} = dt), do: DateTime.to_date(dt)
  defp to_date(%NaiveDateTime{} = ndt), do: NaiveDateTime.to_date(ndt)
end
