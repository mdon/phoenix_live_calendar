defmodule LiveCalendar.ResourceTest do
  use ExUnit.Case, async: true

  alias LiveCalendar.Resource

  @resources [
    %Resource{id: "floor-1", title: "First Floor", order: 1},
    %Resource{id: "floor-2", title: "Second Floor", order: 2},
    %Resource{id: "room-101", title: "Room 101", parent_id: "floor-1", order: 1},
    %Resource{id: "room-102", title: "Room 102", parent_id: "floor-1", order: 2},
    %Resource{id: "room-201", title: "Room 201", parent_id: "floor-2", order: 1}
  ]

  describe "roots/1" do
    test "returns only root resources" do
      roots = Resource.roots(@resources)
      assert length(roots) == 2
      assert Enum.all?(roots, &is_nil(&1.parent_id))
    end

    test "returns sorted by order" do
      roots = Resource.roots(@resources)
      assert hd(roots).id == "floor-1"
    end
  end

  describe "children/2" do
    test "returns children of a resource" do
      parent = Enum.find(@resources, &(&1.id == "floor-1"))
      children = Resource.children(parent, @resources)
      assert length(children) == 2
      assert Enum.all?(children, &(&1.parent_id == "floor-1"))
    end

    test "returns empty list for leaf resources" do
      leaf = Enum.find(@resources, &(&1.id == "room-101"))
      assert Resource.children(leaf, @resources) == []
    end
  end

  describe "to_tree/1" do
    test "builds hierarchical tree" do
      tree = Resource.to_tree(@resources)
      assert length(tree) == 2

      {floor1, floor1_children} = hd(tree)
      assert floor1.id == "floor-1"
      assert length(floor1_children) == 2
    end
  end

  describe "root?/1" do
    test "returns true for root resources" do
      assert Resource.root?(%Resource{id: "1", title: "Root"})
    end

    test "returns false for child resources" do
      refute Resource.root?(%Resource{id: "1", title: "Child", parent_id: "parent"})
    end
  end
end
