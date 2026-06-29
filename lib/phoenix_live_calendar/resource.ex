defmodule PhoenixLiveCalendar.Resource do
  @moduledoc """
  Represents a schedulable resource such as a room, person, or piece of equipment.

  Resources are displayed as columns (in day/week resource views) or rows
  (in timeline views). Events link to resources via `resource_id` or `resource_ids`.

  ## Examples

      # Simple room
      %PhoenixLiveCalendar.Resource{id: "room-a", title: "Conference Room A"}

      # Person with type
      %PhoenixLiveCalendar.Resource{
        id: "dr-smith",
        title: "Dr. Smith",
        type: :person,
        color: "bg-accent"
      }

      # Hierarchical: building > room
      %PhoenixLiveCalendar.Resource{id: "floor-1", title: "First Floor"}
      %PhoenixLiveCalendar.Resource{id: "room-101", title: "Room 101", parent_id: "floor-1"}
  """

  @enforce_keys [:id, :title]
  defstruct [
    :id,
    :title,
    :parent_id,
    :color,
    :type,
    :order,
    extra: %{}
  ]

  @type t :: %__MODULE__{
          id: term(),
          title: String.t(),
          parent_id: term() | nil,
          color: String.t() | nil,
          type: atom() | nil,
          order: integer() | nil,
          extra: map()
        }

  @doc """
  Returns the children of this resource from a flat list of resources.
  """
  @spec children(t(), [t()]) :: [t()]
  def children(%__MODULE__{id: id}, resources) do
    resources
    |> Enum.filter(&(&1.parent_id == id))
    |> Enum.sort_by(& &1.order)
  end

  @doc """
  Returns whether this resource is a root (has no parent).
  """
  @spec root?(t()) :: boolean()
  def root?(%__MODULE__{parent_id: nil}), do: true
  def root?(%__MODULE__{}), do: false

  @doc """
  Returns only root-level resources from a list, sorted by order.
  """
  @spec roots([t()]) :: [t()]
  def roots(resources) do
    resources
    |> Enum.filter(&root?/1)
    |> Enum.sort_by(& &1.order)
  end

  @doc """
  Builds a tree structure from a flat list of resources.

  Returns a list of `{resource, children}` tuples where children
  is recursively structured the same way.
  """
  @spec to_tree([t()]) :: [{t(), list()}]
  def to_tree(resources) do
    roots(resources)
    |> Enum.map(fn resource ->
      {resource, build_children(resource, resources)}
    end)
  end

  defp build_children(resource, all_resources) do
    children(resource, all_resources)
    |> Enum.map(fn child ->
      {child, build_children(child, all_resources)}
    end)
  end
end
