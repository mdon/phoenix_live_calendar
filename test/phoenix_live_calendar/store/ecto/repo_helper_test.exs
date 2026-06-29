defmodule RepoHelperFakeRepo do
  @moduledoc false
  def all(q, opts), do: {:all, q, opts}
  def get(q, id, opts), do: {:get, q, id, opts}
  def insert(cs, opts), do: {:insert, cs, opts}
  def update(cs, opts), do: {:update, cs, opts}
  def delete(s, opts), do: {:delete, s, opts}
  def one(q, opts), do: {:one, q, opts}
end

defmodule PhoenixLiveCalendar.Store.Ecto.RepoHelperTest do
  # async: false — these mutate the global :phoenix_live_calendar, :repo app env.
  use ExUnit.Case, async: false

  alias PhoenixLiveCalendar.Store.Ecto.RepoHelper

  setup do
    prev = Application.get_env(:phoenix_live_calendar, :repo)

    on_exit(fn ->
      if prev,
        do: Application.put_env(:phoenix_live_calendar, :repo, prev),
        else: Application.delete_env(:phoenix_live_calendar, :repo)
    end)

    :ok
  end

  describe "repo/0" do
    test "returns the configured repo module" do
      Application.put_env(:phoenix_live_calendar, :repo, RepoHelperFakeRepo)
      assert RepoHelper.repo() == RepoHelperFakeRepo
    end

    test "raises a helpful error when no repo is configured" do
      Application.delete_env(:phoenix_live_calendar, :repo)
      assert_raise RuntimeError, ~r/No Ecto repository configured/, fn -> RepoHelper.repo() end
    end
  end

  describe "delegation to the configured repo" do
    setup do
      Application.put_env(:phoenix_live_calendar, :repo, RepoHelperFakeRepo)
    end

    test "all/2" do
      assert RepoHelper.all(:q) == {:all, :q, []}
      assert RepoHelper.all(:q, prefix: "p") == {:all, :q, [prefix: "p"]}
    end

    test "get/3" do
      assert RepoHelper.get(:q, 1) == {:get, :q, 1, []}
    end

    test "insert/2" do
      assert RepoHelper.insert(:cs) == {:insert, :cs, []}
    end

    test "update/2" do
      assert RepoHelper.update(:cs) == {:update, :cs, []}
    end

    test "delete/2" do
      assert RepoHelper.delete(:s) == {:delete, :s, []}
    end

    test "one/2" do
      assert RepoHelper.one(:q) == {:one, :q, []}
    end
  end
end
