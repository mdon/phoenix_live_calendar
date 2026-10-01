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

  describe "install_status/1" do
    defp write!(root, rel, content) do
      path = Path.join(root, rel)
      File.mkdir_p!(Path.dirname(path))
      File.write!(path, content)
    end

    @tag :tmp_dir
    test "is :unknown when the host has no stylesheet to judge by", %{tmp_dir: root} do
      assert PhoenixLiveCalendar.install_status(root) == :unknown
    end

    @tag :tmp_dir
    test "is :missing when the host's stylesheet doesn't name the package", %{tmp_dir: root} do
      write!(root, "assets/css/app.css", ~s|@import "tailwindcss";\n@source "../js";\n|)
      assert PhoenixLiveCalendar.install_status(root) == :missing
    end

    @tag :tmp_dir
    test "is :installed from an @source line", %{tmp_dir: root} do
      write!(root, "assets/css/app.css", ~s|@source "../../deps/phoenix_live_calendar";\n|)
      assert PhoenixLiveCalendar.install_status(root) == :installed
    end

    @tag :tmp_dir
    test "is :installed from a Tailwind v3 content glob", %{tmp_dir: root} do
      write!(root, "assets/css/app.css", "@tailwind base;\n")

      write!(
        root,
        "assets/tailwind.config.js",
        ~s|module.exports = {content: ["../deps/phoenix_live_calendar/**/*.ex"]}\n|
      )

      assert PhoenixLiveCalendar.install_status(root) == :installed
    end

    @tag :tmp_dir
    test "is :installed from an umbrella child app's stylesheet", %{tmp_dir: root} do
      write!(
        root,
        "apps/web/assets/css/app.css",
        ~s|@source "../../../../deps/phoenix_live_calendar";\n|
      )

      assert PhoenixLiveCalendar.install_status(root) == :installed
    end

    @tag :tmp_dir
    test "is :installed from a generated sources file", %{tmp_dir: root} do
      write!(root, "assets/css/app.css", ~s|@import "./_phoenix_kit_sources.css";\n|)

      write!(
        root,
        "assets/css/_phoenix_kit_sources.css",
        ~s|@source "../../deps/phoenix_live_calendar";\n|
      )

      assert PhoenixLiveCalendar.install_status(root) == :installed
    end

    @tag :tmp_dir
    test "is :unknown while a generated sources file is absent or not regenerated yet",
         %{tmp_dir: root} do
      write!(root, "assets/css/app.css", ~s|@import "./_phoenix_kit_sources.css";\n|)
      assert PhoenixLiveCalendar.install_status(root) == :unknown

      write!(root, "assets/css/_phoenix_kit_sources.css", ~s|@source "../../deps/other";\n|)
      assert PhoenixLiveCalendar.install_status(root) == :unknown
    end

    @tag :tmp_dir
    test "is :installed when the whole deps directory is a source", %{tmp_dir: root} do
      write!(root, "assets/css/app.css", ~s|@import "tailwindcss";\n@source "../../deps";\n|)
      assert PhoenixLiveCalendar.install_status(root) == :installed
    end

    @tag :tmp_dir
    test "is :installed from a stylesheet nested under assets/css", %{tmp_dir: root} do
      write!(root, "assets/css/app.css", ~s|@import "./sources/calendar.css";\n|)

      write!(
        root,
        "assets/css/sources/calendar.css",
        ~s|@source "../../../deps/phoenix_live_calendar";\n|
      )

      assert PhoenixLiveCalendar.install_status(root) == :installed
    end

    @tag :tmp_dir
    test "ignores a file too large to be a hand-written stylesheet", %{tmp_dir: root} do
      write!(root, "assets/css/app.css", String.duplicate("a{}", 400_000))
      assert PhoenixLiveCalendar.install_status(root) == :unknown
    end

    @tag :tmp_dir
    test "judges every candidate root together", %{tmp_dir: root} do
      write!(root, "app/assets/css/app.css", ~s|@source "../../deps/phoenix_live_calendar";\n|)

      assert PhoenixLiveCalendar.install_status([Path.join(root, "cache"), Path.join(root, "app")]) ==
               :installed
    end

    test "installed?/0 agrees with install_status/0" do
      assert PhoenixLiveCalendar.installed?() ==
               (PhoenixLiveCalendar.install_status() == :installed)
    end
  end

  describe "host_roots/1" do
    # Mix compiles a dependency from inside the dependency's own directory and
    # hands it the HOST's absolute :deps_path and :lockfile — the only trace of
    # where the host lives. A cwd-relative lookup can never see its stylesheets.
    test "is the directory holding the host's lockfile and deps" do
      assert PhoenixLiveCalendar.host_roots(
               deps_path: "/srv/app/deps",
               lockfile: "/srv/app/mix.lock"
             ) == ["/srv/app"]
    end

    test "offers both directories under a custom deps path, the lockfile's first" do
      assert PhoenixLiveCalendar.host_roots(
               deps_path: "/var/cache/acme/deps",
               lockfile: "/srv/app/mix.lock"
             ) == ["/srv/app", "/var/cache/acme"]
    end

    test "falls back to the working directory without a Mix config" do
      assert PhoenixLiveCalendar.host_roots([]) == [File.cwd!()]
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
