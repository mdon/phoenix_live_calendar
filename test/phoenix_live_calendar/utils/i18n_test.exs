defmodule PhoenixLiveCalendar.Utils.I18nTest do
  use ExUnit.Case, async: true

  alias PhoenixLiveCalendar.Utils.I18n

  describe "day_name/2" do
    test "returns English day names by default" do
      assert I18n.day_name(1) == "Monday"
      assert I18n.day_name(7) == "Sunday"
    end

    test "supports custom translations" do
      translations = %{day_names: %{1 => "Lundi", 2 => "Mardi"}}
      assert I18n.day_name(1, translations) == "Lundi"
      assert I18n.day_name(3, translations) == "Wednesday"
    end
  end

  describe "ordered_day_names_short/2" do
    test "starts on Monday by default" do
      names = I18n.ordered_day_names_short(1)
      assert hd(names) == "Mon"
      assert List.last(names) == "Sun"
    end

    test "starts on Sunday when configured" do
      names = I18n.ordered_day_names_short(7)
      assert hd(names) == "Sun"
      assert List.last(names) == "Sat"
    end

    test "starts on Saturday" do
      names = I18n.ordered_day_names_short(6)
      assert hd(names) == "Sat"
    end
  end

  describe "month_name/2" do
    test "returns English month names" do
      assert I18n.month_name(1) == "January"
      assert I18n.month_name(12) == "December"
    end

    test "supports custom translations" do
      translations = %{month_names: %{4 => "Avril"}}
      assert I18n.month_name(4, translations) == "Avril"
    end
  end

  describe "label/3" do
    test "returns default labels" do
      assert I18n.label(:today) == "Today"
      assert I18n.label(:no_events) == "No events"
    end

    test "supports interpolation" do
      assert I18n.label(:more, %{}, %{count: 5}) == "+5 more"
    end

    test "supports custom translations" do
      translations = %{labels: %{today: "Aujourd'hui"}}
      assert I18n.label(:today, translations) == "Aujourd'hui"
    end
  end

  describe "format_title/3" do
    test "formats month title" do
      assert I18n.format_title(:month, ~D[2026-04-15]) == "April 2026"
    end

    test "formats day title" do
      assert I18n.format_title(:day, ~D[2026-04-01]) == "Wednesday, April 1, 2026"
    end

    test "formats year title" do
      assert I18n.format_title(:year, ~D[2026-06-15]) == "2026"
    end

    test "timeline and resource use the full day label" do
      assert I18n.format_title(:timeline, ~D[2026-04-01]) == "Wednesday, April 1, 2026"
      assert I18n.format_title(:resource, ~D[2026-04-01]) == "Wednesday, April 1, 2026"
    end

    test "an unrecognised view falls back to a day label instead of crashing" do
      assert I18n.format_title(:something_new, ~D[2026-04-01]) == "Wednesday, April 1, 2026"
    end
  end

  describe "format_time/2" do
    test "formats 24-hour time" do
      assert I18n.format_time(~T[14:30:00]) == "14:30"
      assert I18n.format_time(~T[09:05:00]) == "09:05"
    end

    test "formats 12-hour time" do
      assert I18n.format_time(~T[14:30:00], format: :h12) == "2:30 PM"
      assert I18n.format_time(~T[09:05:00], format: :h12) == "9:05 AM"
      assert I18n.format_time(~T[00:00:00], format: :h12) == "12:00 AM"
      assert I18n.format_time(~T[12:00:00], format: :h12) == "12:00 PM"
    end
  end

  describe "format_date/2" do
    test "formats date for agenda view" do
      assert I18n.format_date(~D[2026-04-01]) == "Wed, Apr 1"
    end
  end
end
