defmodule PhoenixLiveCalendar.Store.Ecto.MigrationsTest do
  use ExUnit.Case, async: true

  alias PhoenixLiveCalendar.Store.Ecto.Migrations

  test "current_version/0 reports the latest schema version" do
    assert Migrations.current_version() == 1
  end
end
