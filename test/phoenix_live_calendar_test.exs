defmodule PhoenixLiveCalendarTest do
  use ExUnit.Case

  alias PhoenixLiveCalendar.{Availability, BookingConfig, Event, Resource}

  describe "event/3" do
    test "creates an event with required fields" do
      event = PhoenixLiveCalendar.event("1", ~D[2026-04-01])
      assert %Event{id: "1", start: ~D[2026-04-01]} = event
    end

    test "creates an event with optional fields" do
      event =
        PhoenixLiveCalendar.event("1", ~U[2026-04-01 10:00:00Z],
          title: "Meeting",
          color: "bg-primary"
        )

      assert event.title == "Meeting"
      assert event.color == "bg-primary"
    end
  end

  describe "resource/3" do
    test "creates a resource" do
      resource = PhoenixLiveCalendar.resource("room-a", "Conference Room A")
      assert %Resource{id: "room-a", title: "Conference Room A"} = resource
    end
  end

  describe "availability/4" do
    test "creates recurring availability" do
      avail = PhoenixLiveCalendar.availability([1, 2, 3, 4, 5], ~T[09:00:00], ~T[17:00:00])
      assert %Availability{days_of_week: [1, 2, 3, 4, 5]} = avail
    end

    test "creates date-specific availability" do
      avail = PhoenixLiveCalendar.availability(~D[2026-04-15], ~T[10:00:00], ~T[14:00:00])
      assert %Availability{date: ~D[2026-04-15]} = avail
    end
  end

  describe "booking_config/1" do
    test "creates a booking config with defaults" do
      config = PhoenixLiveCalendar.booking_config()
      assert %BookingConfig{duration: 30, seats: 1} = config
    end

    test "creates a booking config with custom values" do
      config = PhoenixLiveCalendar.booking_config(duration: 60, buffer_after: 10)
      assert config.duration == 60
      assert config.buffer_after == 10
    end
  end

  describe "to_events/1" do
    test "passes through Event structs" do
      events = [PhoenixLiveCalendar.event("1", ~D[2026-04-01])]
      assert [%Event{id: "1"}] = PhoenixLiveCalendar.to_events(events)
    end
  end
end
