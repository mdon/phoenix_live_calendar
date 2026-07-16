defmodule PhoenixLiveCalendar.Utils.SizingTest do
  use ExUnit.Case, async: true

  alias PhoenixLiveCalendar.Utils.Sizing

  describe "parse_rem/2" do
    test "parses rem and px values" do
      assert Sizing.parse_rem("3rem") == 3.0
      assert Sizing.parse_rem("1.25rem") == 1.25
      assert Sizing.parse_rem("48px") == 3.0
      assert Sizing.parse_rem("8px") == 0.5
    end

    test "trims surrounding whitespace" do
      assert Sizing.parse_rem(" 2rem ") == 2.0
    end

    test "unparseable values fall back to the default" do
      assert Sizing.parse_rem("calc(100% - 2rem)", 4.0) == 4.0
      assert Sizing.parse_rem("50%", 4.0) == 4.0
      assert Sizing.parse_rem("3 rem", 4.0) == 4.0
      assert Sizing.parse_rem("", 4.0) == 4.0
      assert Sizing.parse_rem(nil, 4.0) == 4.0
    end

    test "the default always comes back as a float" do
      assert Sizing.parse_rem(nil, 3) === 3.0
      assert Sizing.parse_rem("bogus", 2) === 2.0
    end

    test "zero and negative dimensions parse through unchanged" do
      # estimation only — the CSS path sanitizes separately
      assert Sizing.parse_rem("0rem") == 0.0
      assert Sizing.parse_rem("-3rem") == -3.0
    end
  end

  describe "label_rem/1" do
    test "nil is zero-width" do
      assert Sizing.label_rem(nil) == 0.0
    end

    test "estimates padding plus per-grapheme width" do
      assert Sizing.label_rem("") == 0.5
      assert Sizing.label_rem("abcd") == 0.5 + 4 * 0.45
    end

    test "counts graphemes, not bytes" do
      assert Sizing.label_rem("héllo") == Sizing.label_rem("hello")
    end
  end
end
