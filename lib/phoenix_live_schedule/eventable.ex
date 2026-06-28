defprotocol PhoenixLiveSchedule.Eventable do
  @moduledoc """
  Optional protocol for auto-converting domain structs to `PhoenixLiveSchedule.Event`.

  Implement this protocol on your application's structs to enable automatic
  conversion when passing data to calendar components. If you don't implement
  this protocol, build `PhoenixLiveSchedule.Event` structs manually.

  ## Example

      defimpl PhoenixLiveSchedule.Eventable, for: MyApp.Appointment do
        def to_event(appointment) do
          %PhoenixLiveSchedule.Event{
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

      events = Enum.map(appointments, &PhoenixLiveSchedule.Eventable.to_event/1)
  """

  @doc """
  Converts a domain struct to a `PhoenixLiveSchedule.Event`.
  """
  @spec to_event(t) :: PhoenixLiveSchedule.Event.t()
  def to_event(source)
end

# PhoenixLiveSchedule.Event implements the protocol as an identity function
defimpl PhoenixLiveSchedule.Eventable, for: PhoenixLiveSchedule.Event do
  def to_event(event), do: event
end
