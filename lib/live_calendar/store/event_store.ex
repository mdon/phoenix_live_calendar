defmodule LiveCalendar.Store.EventStore do
  @moduledoc """
  Behaviour defining the data access interface for calendar events.

  Implement this behaviour to provide custom persistence.
  A default Ecto implementation is provided in `LiveCalendar.Store.Ecto.EventStoreEcto`.

  ## Example custom implementation

      defmodule MyApp.InMemoryEventStore do
        @behaviour LiveCalendar.Store.EventStore

        @impl true
        def list_events(opts) do
          # Your custom implementation
        end

        @impl true
        def get_event(id, _opts) do
          # Your custom implementation
        end

        # ... etc
      end

  Configure your store:

      config :live_calendar, event_store: MyApp.InMemoryEventStore
  """

  @type event_id :: term()
  @type opts :: keyword()

  @doc """
  Lists events within a date range.

  ## Options

  - `:start` — Range start (Date or DateTime)
  - `:end` — Range end (Date or DateTime, exclusive)
  - `:resource_id` — Filter by resource
  - `:calendar_id` — Filter by calendar
  - `:limit` — Maximum events to return
  """
  @callback list_events(opts()) :: [LiveCalendar.Event.t()]

  @doc "Fetches a single event by ID."
  @callback get_event(event_id(), opts()) :: LiveCalendar.Event.t() | nil

  @doc "Creates a new event. Returns `{:ok, event}` or `{:error, changeset}`."
  @callback create_event(map(), opts()) :: {:ok, LiveCalendar.Event.t()} | {:error, term()}

  @doc "Updates an existing event."
  @callback update_event(event_id(), map(), opts()) ::
              {:ok, LiveCalendar.Event.t()} | {:error, term()}

  @doc "Deletes an event by ID."
  @callback delete_event(event_id(), opts()) :: :ok | {:error, term()}

  @optional_callbacks [get_event: 2, create_event: 2, update_event: 3, delete_event: 2]
end
