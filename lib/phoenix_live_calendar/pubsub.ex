defmodule PhoenixLiveCalendar.PubSub do
  @moduledoc """
  Optional PubSub integration for real-time calendar updates.

  When a topic is configured, the calendar component subscribes to live updates
  so all users viewing the same calendar see changes in real time.

  ## Usage

  ### In your LiveView

      def mount(_params, _session, socket) do
        # Subscribe to calendar updates
        PhoenixLiveCalendar.PubSub.subscribe("calendar:my-calendar-id")
        {:ok, socket}
      end

      def handle_info({:phoenix_live_calendar, event, payload}, socket) do
        # Handle calendar events — update your events list
        case event do
          :event_created -> ...
          :event_updated -> ...
          :event_deleted -> ...
          :events_bulk_updated -> ...
        end
      end

  ### Broadcasting changes (from your context modules)

      # After creating an event
      PhoenixLiveCalendar.PubSub.broadcast("calendar:my-calendar-id", :event_created, new_event)

      # After updating
      PhoenixLiveCalendar.PubSub.broadcast("calendar:my-calendar-id", :event_updated, updated_event)

      # After deleting
      PhoenixLiveCalendar.PubSub.broadcast("calendar:my-calendar-id", :event_deleted, %{id: event_id})

      # Bulk operations — single broadcast
      PhoenixLiveCalendar.PubSub.broadcast("calendar:my-calendar-id", :events_bulk_updated, %{ids: event_ids})

  ## Configuration

  Set the PubSub server in your config (defaults to your app's PubSub):

      config :phoenix_live_calendar, pubsub_server: MyApp.PubSub

  Or pass it explicitly:

      PhoenixLiveCalendar.PubSub.subscribe("topic", pubsub: MyApp.PubSub)
  """

  @doc """
  Subscribes the current process to a calendar topic.

  ## Options

  - `pubsub` — The PubSub server module (default: from config)
  """
  @spec subscribe(String.t(), keyword()) :: :ok | {:error, term()}
  def subscribe(topic, opts \\ []) do
    pubsub = pubsub_server(opts)

    if pubsub do
      Phoenix.PubSub.subscribe(pubsub, topic)
    else
      {:error, :no_pubsub_configured}
    end
  end

  @doc """
  Unsubscribes the current process from a calendar topic.
  """
  @spec unsubscribe(String.t(), keyword()) :: :ok
  def unsubscribe(topic, opts \\ []) do
    pubsub = pubsub_server(opts)

    if pubsub do
      Phoenix.PubSub.unsubscribe(pubsub, topic)
    else
      :ok
    end
  end

  @doc """
  Broadcasts a calendar event to all subscribers of a topic.

  The message is sent as `{:phoenix_live_calendar, event_type, payload}`.

  ## Parameters

  - `topic` — The PubSub topic
  - `event_type` — An atom describing the event (e.g., `:event_created`)
  - `payload` — The data associated with the event
  - `opts` — Options (`:pubsub` to specify the PubSub server)
  """
  @spec broadcast(String.t(), atom(), term(), keyword()) :: :ok | {:error, term()}
  def broadcast(topic, event_type, payload, opts \\ []) do
    pubsub = pubsub_server(opts)

    if pubsub do
      Phoenix.PubSub.broadcast(pubsub, topic, {:phoenix_live_calendar, event_type, payload})
    else
      {:error, :no_pubsub_configured}
    end
  end

  @doc """
  Broadcasts a calendar event to all subscribers except the sender.

  Useful when the sender already has the updated state and doesn't
  need to re-process their own broadcast.
  """
  @spec broadcast_from(String.t(), atom(), term(), keyword()) :: :ok | {:error, term()}
  def broadcast_from(topic, event_type, payload, opts \\ []) do
    pubsub = pubsub_server(opts)

    if pubsub do
      Phoenix.PubSub.broadcast_from(
        pubsub,
        self(),
        topic,
        {:phoenix_live_calendar, event_type, payload}
      )
    else
      {:error, :no_pubsub_configured}
    end
  end

  @doc """
  Generates a scoped topic string for a calendar.

  ## Examples

      iex> PhoenixLiveCalendar.PubSub.topic("my-calendar")
      "phoenix_live_calendar:my-calendar"

      iex> PhoenixLiveCalendar.PubSub.topic("my-calendar", resource_id: "room-a")
      "phoenix_live_calendar:my-calendar:room-a"
  """
  @spec topic(String.t(), keyword()) :: String.t()
  def topic(calendar_id, opts \\ []) do
    base = "phoenix_live_calendar:#{calendar_id}"

    case Keyword.get(opts, :resource_id) do
      nil -> base
      resource_id -> "#{base}:#{resource_id}"
    end
  end

  # -- Private --

  defp pubsub_server(opts) do
    Keyword.get(opts, :pubsub) ||
      Application.get_env(:phoenix_live_calendar, :pubsub_server)
  end
end
