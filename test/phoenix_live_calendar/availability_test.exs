defmodule PhoenixLiveCalendar.AvailabilityTest do
  use ExUnit.Case, async: true

  alias PhoenixLiveCalendar.Availability

  describe "applies_on?/2" do
    test "date-specific availability matches exact date" do
      avail = %Availability{date: ~D[2026-04-15], start_time: ~T[09:00:00], end_time: ~T[17:00:00]}
      assert Availability.applies_on?(avail, ~D[2026-04-15])
      refute Availability.applies_on?(avail, ~D[2026-04-16])
    end

    test "recurring availability matches day of week" do
      # Monday=1, Wednesday=3, Friday=5
      avail = %Availability{
        days_of_week: [1, 3, 5],
        start_time: ~T[09:00:00],
        end_time: ~T[17:00:00]
      }

      # 2026-04-01 is Wednesday (3)
      assert Availability.applies_on?(avail, ~D[2026-04-01])
      # 2026-04-02 is Thursday (4)
      refute Availability.applies_on?(avail, ~D[2026-04-02])
      # 2026-04-03 is Friday (5)
      assert Availability.applies_on?(avail, ~D[2026-04-03])
    end
  end

  describe "covers_time?/2" do
    test "time within window" do
      avail = %Availability{start_time: ~T[09:00:00], end_time: ~T[17:00:00]}
      assert Availability.covers_time?(avail, ~T[10:00:00])
      assert Availability.covers_time?(avail, ~T[09:00:00])
    end

    test "time at end boundary is not covered (exclusive)" do
      avail = %Availability{start_time: ~T[09:00:00], end_time: ~T[17:00:00]}
      refute Availability.covers_time?(avail, ~T[17:00:00])
    end

    test "time before window" do
      avail = %Availability{start_time: ~T[09:00:00], end_time: ~T[17:00:00]}
      refute Availability.covers_time?(avail, ~T[08:59:00])
    end
  end

  describe "windows_for_date/3" do
    test "returns matching recurring windows" do
      availabilities = [
        %Availability{
          days_of_week: [1, 2, 3, 4, 5],
          start_time: ~T[09:00:00],
          end_time: ~T[12:00:00]
        },
        %Availability{
          days_of_week: [1, 2, 3, 4, 5],
          start_time: ~T[13:00:00],
          end_time: ~T[17:00:00]
        }
      ]

      # 2026-04-01 is Wednesday (3)
      windows = Availability.windows_for_date(availabilities, ~D[2026-04-01])
      assert length(windows) == 2
    end

    test "date override takes precedence over recurring" do
      availabilities = [
        %Availability{
          days_of_week: [1, 2, 3, 4, 5],
          start_time: ~T[09:00:00],
          end_time: ~T[17:00:00]
        },
        %Availability{date: ~D[2026-04-01], start_time: ~T[10:00:00], end_time: ~T[14:00:00]}
      ]

      windows = Availability.windows_for_date(availabilities, ~D[2026-04-01])
      assert length(windows) == 1
      assert hd(windows).start_time == ~T[10:00:00]
    end

    test "filters by resource_id" do
      availabilities = [
        %Availability{
          days_of_week: [1, 2, 3, 4, 5],
          start_time: ~T[09:00:00],
          end_time: ~T[17:00:00]
        },
        %Availability{
          days_of_week: [1, 2, 3, 4, 5],
          start_time: ~T[08:00:00],
          end_time: ~T[12:00:00],
          resource_id: "dr-smith"
        }
      ]

      # Without resource filter, gets only the global one (resource_id: nil matches nil)
      windows = Availability.windows_for_date(availabilities, ~D[2026-04-01])
      assert length(windows) == 1

      # With resource filter, gets both global (nil) and resource-specific
      windows = Availability.windows_for_date(availabilities, ~D[2026-04-01], "dr-smith")
      assert length(windows) == 2
    end

    test "returns empty for non-matching days" do
      availabilities = [
        %Availability{days_of_week: [1, 3, 5], start_time: ~T[09:00:00], end_time: ~T[17:00:00]}
      ]

      # 2026-04-02 is Thursday (4)
      windows = Availability.windows_for_date(availabilities, ~D[2026-04-02])
      assert windows == []
    end
  end
end
