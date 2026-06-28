defmodule LiveCalendar.Utils.I18n do
  @moduledoc """
  Internationalization helpers for calendar labels, day names, month names,
  and date/time formatting.

  Provides default English translations with full override support via a
  translations map. Consumers can either:

  1. Pass a `translations` map to override specific labels
  2. Use Gettext in their own app and pass translated strings directly

  ## Day numbering

  Uses ISO day numbering: 1 = Monday, 7 = Sunday.

  ## Examples

      # Default English
      I18n.day_name(1)
      #=> "Monday"

      # With custom translations
      translations = %{day_names: %{1 => "Lundi", 2 => "Mardi", ...}}
      I18n.day_name(1, translations)
      #=> "Lundi"

      # Short names
      I18n.day_name_short(1)
      #=> "Mon"
  """

  alias LiveCalendar.Utils.DateHelpers

  @default_day_names %{
    1 => "Monday",
    2 => "Tuesday",
    3 => "Wednesday",
    4 => "Thursday",
    5 => "Friday",
    6 => "Saturday",
    7 => "Sunday"
  }

  @default_day_names_short %{
    1 => "Mon",
    2 => "Tue",
    3 => "Wed",
    4 => "Thu",
    5 => "Fri",
    6 => "Sat",
    7 => "Sun"
  }

  @default_day_names_narrow %{
    1 => "M",
    2 => "T",
    3 => "W",
    4 => "T",
    5 => "F",
    6 => "S",
    7 => "S"
  }

  @default_month_names %{
    1 => "January",
    2 => "February",
    3 => "March",
    4 => "April",
    5 => "May",
    6 => "June",
    7 => "July",
    8 => "August",
    9 => "September",
    10 => "October",
    11 => "November",
    12 => "December"
  }

  @default_month_names_short %{
    1 => "Jan",
    2 => "Feb",
    3 => "Mar",
    4 => "Apr",
    5 => "May",
    6 => "Jun",
    7 => "Jul",
    8 => "Aug",
    9 => "Sep",
    10 => "Oct",
    11 => "Nov",
    12 => "Dec"
  }

  @default_labels %{
    today: "Today",
    month: "Month",
    week: "Week",
    day: "Day",
    year: "Year",
    agenda: "Agenda",
    timeline: "Timeline",
    task: "Task",
    ungrouped: "Ungrouped",
    more: "+%{count} more",
    no_events: "No events",
    all_day: "All day",
    prev: "Previous",
    next: "Next",
    prev_month: "Previous month",
    next_month: "Next month",
    prev_week: "Previous week",
    next_week: "Next week",
    prev_day: "Previous day",
    next_day: "Next day",
    prev_year: "Previous year",
    next_year: "Next year",
    go_to_today: "Go to today",
    earlier: "earlier",
    later: "later",
    earlier_tasks: "%{count} earlier",
    later_tasks: "%{count} later"
  }

  @type translations :: %{
          optional(:day_names) => %{(1..7) => String.t()},
          optional(:day_names_short) => %{(1..7) => String.t()},
          optional(:day_names_narrow) => %{(1..7) => String.t()},
          optional(:month_names) => %{(1..12) => String.t()},
          optional(:month_names_short) => %{(1..12) => String.t()},
          optional(:labels) => %{atom() => String.t()}
        }

  # --- Day names ---

  @doc "Returns the full day name for an ISO day number (1-7)."
  @spec day_name(1..7, translations()) :: String.t()
  def day_name(day, translations \\ %{}) do
    get_in(translations, [:day_names, day]) || @default_day_names[day]
  end

  @doc "Returns the abbreviated day name (3 letters)."
  @spec day_name_short(1..7, translations()) :: String.t()
  def day_name_short(day, translations \\ %{}) do
    get_in(translations, [:day_names_short, day]) || @default_day_names_short[day]
  end

  @doc "Returns the narrow day name (1 letter)."
  @spec day_name_narrow(1..7, translations()) :: String.t()
  def day_name_narrow(day, translations \\ %{}) do
    get_in(translations, [:day_names_narrow, day]) || @default_day_names_narrow[day]
  end

  @doc """
  Returns ordered day names for a week, starting from the given week start day.

  ## Examples

      iex> I18n.ordered_day_names_short(1)
      ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

      iex> I18n.ordered_day_names_short(7)
      ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
  """
  @spec ordered_day_names_short(1..7, translations()) :: [String.t()]
  def ordered_day_names_short(week_start \\ 1, translations \\ %{}) do
    ordered_days(week_start)
    |> Enum.map(&day_name_short(&1, translations))
  end

  @doc "Returns ordered full day names for a week."
  @spec ordered_day_names(1..7, translations()) :: [String.t()]
  def ordered_day_names(week_start \\ 1, translations \\ %{}) do
    ordered_days(week_start)
    |> Enum.map(&day_name(&1, translations))
  end

  @doc "Returns ordered narrow day names for a week."
  @spec ordered_day_names_narrow(1..7, translations()) :: [String.t()]
  def ordered_day_names_narrow(week_start \\ 1, translations \\ %{}) do
    ordered_days(week_start)
    |> Enum.map(&day_name_narrow(&1, translations))
  end

  # --- Month names ---

  @doc "Returns the full month name."
  @spec month_name(1..12, translations()) :: String.t()
  def month_name(month, translations \\ %{}) do
    get_in(translations, [:month_names, month]) || @default_month_names[month]
  end

  @doc "Returns the abbreviated month name."
  @spec month_name_short(1..12, translations()) :: String.t()
  def month_name_short(month, translations \\ %{}) do
    get_in(translations, [:month_names_short, month]) || @default_month_names_short[month]
  end

  # --- Labels ---

  @doc """
  Returns a translated label string.

  Supports interpolation with a bindings map.

  ## Examples

      iex> I18n.label(:today)
      "Today"

      iex> I18n.label(:more, %{}, %{count: 5})
      "+5 more"
  """
  @spec label(atom(), translations(), map()) :: String.t()
  def label(key, translations \\ %{}, bindings \\ %{}) do
    text = get_in(translations, [:labels, key]) || @default_labels[key] || to_string(key)
    interpolate(text, bindings)
  end

  # --- Title formatting ---

  @doc """
  Formats a title string for the calendar header based on view mode and date.

  ## Examples

      iex> I18n.format_title(:month, ~D[2026-04-15])
      "April 2026"

      iex> I18n.format_title(:week, ~D[2026-04-15])
      "Apr 13 – 19, 2026"

      iex> I18n.format_title(:day, ~D[2026-04-15])
      "Wednesday, April 15, 2026"

      iex> I18n.format_title(:year, ~D[2026-04-15])
      "2026"
  """
  @spec format_title(atom(), Date.t(), keyword()) :: String.t()
  def format_title(view, date, opts \\ [])

  def format_title(:month, %Date{} = date, opts) do
    translations = Keyword.get(opts, :translations, %{})
    "#{month_name(date.month, translations)} #{date.year}"
  end

  def format_title(:week, %Date{} = date, opts) do
    week_start = Keyword.get(opts, :week_start, 1)
    translations = Keyword.get(opts, :translations, %{})

    start_date = DateHelpers.week_start_date(date, week_start)
    end_date = DateHelpers.week_end_date(date, week_start)

    if start_date.month == end_date.month do
      "#{month_name_short(start_date.month, translations)} #{start_date.day} \u2013 #{end_date.day}, #{end_date.year}"
    else
      if start_date.year == end_date.year do
        "#{month_name_short(start_date.month, translations)} #{start_date.day} \u2013 #{month_name_short(end_date.month, translations)} #{end_date.day}, #{end_date.year}"
      else
        "#{month_name_short(start_date.month, translations)} #{start_date.day}, #{start_date.year} \u2013 #{month_name_short(end_date.month, translations)} #{end_date.day}, #{end_date.year}"
      end
    end
  end

  def format_title(:day, %Date{} = date, opts) do
    translations = Keyword.get(opts, :translations, %{})
    day_of_week = Date.day_of_week(date)

    "#{day_name(day_of_week, translations)}, #{month_name(date.month, translations)} #{date.day}, #{date.year}"
  end

  def format_title(:year, %Date{} = date, _opts) do
    "#{date.year}"
  end

  def format_title({:n_day, _n}, %Date{} = date, opts) do
    format_title(:week, date, opts)
  end

  def format_title(:agenda, %Date{} = date, opts) do
    format_title(:month, date, opts)
  end

  # --- Time formatting ---

  @doc """
  Formats a time value for display.

  ## Options

  - `format` — `:h24` (default) or `:h12`

  ## Examples

      iex> I18n.format_time(~T[14:30:00])
      "14:30"

      iex> I18n.format_time(~T[14:30:00], format: :h12)
      "2:30 PM"
  """
  @spec format_time(Time.t(), keyword()) :: String.t()
  def format_time(%Time{} = time, opts \\ []) do
    case Keyword.get(opts, :format, :h24) do
      :h24 ->
        h = String.pad_leading("#{time.hour}", 2, "0")
        m = String.pad_leading("#{time.minute}", 2, "0")
        "#{h}:#{m}"

      :h12 ->
        {h12, period} = to_12h(time.hour)
        m = String.pad_leading("#{time.minute}", 2, "0")
        "#{h12}:#{m} #{period}"
    end
  end

  @doc """
  Formats a date for display in list/agenda views.

  ## Examples

      iex> I18n.format_date(~D[2026-04-15])
      "Wed, Apr 15"
  """
  @spec format_date(Date.t(), translations()) :: String.t()
  def format_date(%Date{} = date, translations \\ %{}) do
    day_of_week = Date.day_of_week(date)

    "#{day_name_short(day_of_week, translations)}, #{month_name_short(date.month, translations)} #{date.day}"
  end

  # --- Private helpers ---

  defp ordered_days(week_start) do
    Enum.map(0..6, fn offset ->
      rem(week_start - 1 + offset, 7) + 1
    end)
  end

  defp interpolate(text, bindings) when bindings == %{}, do: text

  defp interpolate(text, bindings) do
    Enum.reduce(bindings, text, fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", to_string(value))
    end)
  end

  defp to_12h(0), do: {12, "AM"}
  defp to_12h(12), do: {12, "PM"}
  defp to_12h(h) when h < 12, do: {h, "AM"}
  defp to_12h(h), do: {h - 12, "PM"}
end
