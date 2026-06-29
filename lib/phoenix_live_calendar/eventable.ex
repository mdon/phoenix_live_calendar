defprotocol PhoenixLiveCalendar.Eventable do
  @moduledoc """
  Optional protocol for auto-converting domain structs to `PhoenixLiveCalendar.Event`.

  Implement this protocol on your application's structs to enable automatic
  conversion when passing data to calendar components. If you don't implement
  this protocol, build `PhoenixLiveCalendar.Event` structs manually.

  ## Example

      defimpl PhoenixLiveCalendar.Eventable, for: MyApp.Appointment do
        def to_event(appointment) do
          %PhoenixLiveCalendar.Event{
            id: appointment.id,
            title: "\#{appointment.patient_name} - \#{appointment.type}",
            start: appointment.starts_at,
            end: appointment.ends_at,
            resource_id: appointment.provider_id,
            color: color_for_type(appointment.type),
            extra: %{
              patient_id: appointment.patient_id,
              status: appointment.status
            }
          }
        end

        defp color_for_type(:consultation), do: "bg-info"
        defp color_for_type(:procedure), do: "bg-warning"
        defp color_for_type(_), do: "bg-primary"
      end

  Then pass your structs directly:

      events = Enum.map(appointments, &PhoenixLiveCalendar.Eventable.to_event/1)
  """

  @doc """
  Converts a domain struct to a `PhoenixLiveCalendar.Event`.
  """
  @spec to_event(t) :: PhoenixLiveCalendar.Event.t()
  def to_event(source)
end

# PhoenixLiveCalendar.Event implements the protocol as an identity function
defimpl PhoenixLiveCalendar.Eventable, for: PhoenixLiveCalendar.Event do
  def to_event(event), do: event
end
