defmodule PhoenixLiveCalendar.Utils.Safe do
  @moduledoc false
  # Internal helpers for defensive programming.
  # Prevents crashes from bad input data by providing safe fallbacks.

  require Logger

  @doc """
  Safely converts a value to a Date, returning nil on failure.
  """
  def to_date(%Date{} = d), do: d
  def to_date(%DateTime{} = dt), do: DateTime.to_date(dt)
  def to_date(%NaiveDateTime{} = ndt), do: NaiveDateTime.to_date(ndt)

  def to_date(str) when is_binary(str) do
    case Date.from_iso8601(str) do
      {:ok, date} -> date
      _ -> nil
    end
  end

  def to_date(other) do
    Logger.warning("[PhoenixLiveCalendar] Cannot convert to Date: #{inspect(other)}")
    nil
  end

  @doc """
  Safely converts a value to a Time, returning nil on failure.
  """
  def to_time(%Time{} = t), do: t
  def to_time(%DateTime{} = dt), do: DateTime.to_time(dt)
  def to_time(%NaiveDateTime{} = ndt), do: NaiveDateTime.to_time(ndt)

  def to_time(str) when is_binary(str) do
    case Time.from_iso8601(str) do
      {:ok, time} -> time
      _ -> nil
    end
  end

  def to_time(other) do
    Logger.warning("[PhoenixLiveCalendar] Cannot convert to Time: #{inspect(other)}")
    nil
  end

  @doc """
  Wraps a function call in a try/rescue, returning the fallback on any error.
  Logs the error at warning level.
  """
  def safe_call(fun, fallback \\ nil) do
    fun.()
  rescue
    e ->
      Logger.warning("[PhoenixLiveCalendar] Error: #{Exception.message(e)}")
      fallback
  end

  @doc """
  Ensures a value is a list, wrapping non-list values.
  """
  def ensure_list(nil), do: []
  def ensure_list(list) when is_list(list), do: list

  def ensure_list(other) do
    Logger.warning("[PhoenixLiveCalendar] Expected list, got: #{inspect(other)}")
    []
  end

  @doc """
  Ensures a value is a non-negative integer, returning default on failure.
  """
  def ensure_pos_integer(val, _default) when is_integer(val) and val > 0, do: val

  def ensure_pos_integer(val, default) do
    Logger.warning(
      "[PhoenixLiveCalendar] Expected positive integer, got: #{inspect(val)}, using #{default}"
    )

    default
  end

  @doc """
  Validates a CSS dimension value (e.g., "3rem", "48px", "50%", "5vh").
  Returns the value if safe, or a fallback if not.
  """
  def sanitize_css_dimension(value, fallback \\ "3rem")

  def sanitize_css_dimension(value, fallback) when is_binary(value) do
    if Regex.match?(~r/^\d+(\.\d+)?\s*(px|rem|em|vh|vw|%|ch|ex|vmin|vmax)$/, value) do
      value
    else
      Logger.warning(
        "[PhoenixLiveCalendar] Invalid CSS dimension: #{inspect(value)}, using fallback"
      )

      fallback
    end
  end

  def sanitize_css_dimension(_, fallback), do: fallback

  @doc """
  Safely filters events, skipping any that would cause errors.
  """
  def safe_filter_events(events) when is_list(events) do
    Enum.filter(events, fn
      %PhoenixLiveCalendar.Event{id: id, start: start} when not is_nil(id) and not is_nil(start) ->
        true

      invalid ->
        Logger.warning("[PhoenixLiveCalendar] Skipping invalid event: #{inspect(invalid)}")
        false
    end)
  end

  def safe_filter_events(other) do
    Logger.warning("[PhoenixLiveCalendar] Expected event list, got: #{inspect(other)}")
    []
  end

  @doc """
  Infers the daisyUI text content color from a background color class.

  "bg-warning" -> "text-warning-content", "bg-primary/80" -> "text-primary-content", etc.
  Falls back to "text-base-content" for unknown patterns, "text-primary-content" for nil.
  """
  # No color to infer from — assume the surface underneath is base-colored.
  # (Previously "text-primary-content", which paired with EventItem's old
  # missing default background to render invisible white-on-cell text.)
  def infer_text_color(nil), do: "text-base-content"

  def infer_text_color(bg_class) when is_binary(bg_class) do
    case Regex.run(~r/bg-(primary|secondary|accent|neutral|info|success|warning|error)/, bg_class) do
      [_, color] -> "text-#{color}-content"
      _ -> "text-base-content"
    end
  end
end
