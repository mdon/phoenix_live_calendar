defmodule PhoenixLiveCalendar.Layer do
  @moduledoc """
  A named set of events shown or hidden together — "my calendar", a
  teammate, a room, a project.

  Tag events with `layer_id` and pass the layers to the
  `CalendarComponent`; it renders a legend of toggle chips and filters
  hidden layers' events server-side:

      layers = [
        %Layer{id: "me", label: "Me", color: "bg-primary"},
        %Layer{id: "alice", label: "Alice", color: "bg-accent"},
        %Layer{id: "holidays", label: "Holidays", color: "bg-error", visible: false}
      ]

      <.live_component
        module={PhoenixLiveCalendar.CalendarComponent}
        id="team"
        events={@events}
        layers={layers}
        on_layers_change={fn change -> send(self(), {:layers, change}) end}
      />

  - `color`/`text_color` — the layer's identity classes; events without
    their own `color` inherit them, and the legend chip shows the dot
  - `visible: false` — start hidden (the viewer can toggle it on)
  - Access control happens BEFORE the component: a layer the viewer must
    not see is simply never passed in — nothing about it is serialized
    to the client
  - Events with a `layer_id` matching no passed layer are always shown

  Layer visibility state lives in the component; the current split is
  reported through `on_layers_change` as `%{visible: ids, hidden: ids}`.
  """

  @enforce_keys [:id, :label]
  defstruct [
    :id,
    :label,
    :color,
    :text_color,
    visible: true,
    extra: %{}
  ]

  @type t :: %__MODULE__{
          id: term(),
          label: String.t(),
          color: String.t() | atom() | nil,
          text_color: String.t() | nil,
          visible: boolean(),
          extra: map()
        }
end
