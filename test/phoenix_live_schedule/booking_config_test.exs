defmodule PhoenixLiveSchedule.BookingConfigTest do
  use ExUnit.Case, async: true

  alias PhoenixLiveSchedule.BookingConfig

  describe "effective_slot_interval/1" do
    test "returns slot_interval when set" do
      config = %BookingConfig{slot_interval: 15, duration: 30}
      assert BookingConfig.effective_slot_interval(config) == 15
    end

    test "falls back to duration when nil" do
      config = %BookingConfig{duration: 60}
      assert BookingConfig.effective_slot_interval(config) == 60
    end
  end

  describe "effective_min_duration/1" do
    test "returns min_duration when set" do
      config = %BookingConfig{min_duration: 15, duration: 30}
      assert BookingConfig.effective_min_duration(config) == 15
    end

    test "falls back to duration when nil" do
      config = %BookingConfig{duration: 30}
      assert BookingConfig.effective_min_duration(config) == 30
    end
  end

  describe "effective_max_duration/1" do
    test "returns max_duration when set" do
      config = %BookingConfig{max_duration: 120, duration: 30}
      assert BookingConfig.effective_max_duration(config) == 120
    end

    test "falls back to duration when nil" do
      config = %BookingConfig{duration: 30}
      assert BookingConfig.effective_max_duration(config) == 30
    end
  end

  describe "total_blocked_time/1" do
    test "sums buffer + duration + buffer" do
      config = %BookingConfig{duration: 30, buffer_before: 10, buffer_after: 5}
      assert BookingConfig.total_blocked_time(config) == 45
    end

    test "works with zero buffers" do
      config = %BookingConfig{duration: 60}
      assert BookingConfig.total_blocked_time(config) == 60
    end
  end
end
