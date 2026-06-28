if Code.ensure_loaded?(Ecto) do
  defmodule LiveCalendar.Store.Ecto.RepoHelper do
    @moduledoc """
    Runtime repo resolution for the optional Ecto layer.

    Resolves the consumer's Ecto repo at runtime via application config:

        config :live_calendar, repo: MyApp.Repo

    Never resolves at compile time (follows Elixir library guidelines).
    """

    @doc """
    Returns the configured Ecto repo module.

    Raises if no repo is configured.
    """
    @spec repo() :: module()
    def repo do
      case Application.get_env(:live_calendar, :repo) do
        nil ->
          raise """
          No Ecto repository configured for LiveCalendar.

          Add to your config:

              config :live_calendar, repo: MyApp.Repo
          """

        repo when is_atom(repo) ->
          repo
      end
    end

    @doc "Delegates to the configured repo's `all/2`."
    def all(queryable, opts \\ []), do: repo().all(queryable, opts)

    @doc "Delegates to the configured repo's `get/3`."
    def get(queryable, id, opts \\ []), do: repo().get(queryable, id, opts)

    @doc "Delegates to the configured repo's `insert/2`."
    def insert(changeset, opts \\ []), do: repo().insert(changeset, opts)

    @doc "Delegates to the configured repo's `update/2`."
    def update(changeset, opts \\ []), do: repo().update(changeset, opts)

    @doc "Delegates to the configured repo's `delete/2`."
    def delete(struct_or_changeset, opts \\ []), do: repo().delete(struct_or_changeset, opts)

    @doc "Delegates to the configured repo's `one/2`."
    def one(queryable, opts \\ []), do: repo().one(queryable, opts)
  end
end
