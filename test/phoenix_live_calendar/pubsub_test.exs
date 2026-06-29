defmodule PhoenixLiveCalendar.PubSubTest do
  use ExUnit.Case, async: true

  alias PhoenixLiveCalendar.PubSub

  describe "topic/2" do
    test "generates basic topic" do
      assert PubSub.topic("my-calendar") == "phoenix_live_calendar:my-calendar"
    end

    test "generates resource-scoped topic" do
      assert PubSub.topic("my-calendar", resource_id: "room-a") ==
               "phoenix_live_calendar:my-calendar:room-a"
    end

    test "without resource_id option" do
      assert PubSub.topic("cal-1", []) == "phoenix_live_calendar:cal-1"
    end
  end

  describe "subscribe/2 without pubsub configured" do
    test "returns error when no pubsub server" do
      assert {:error, :no_pubsub_configured} = PubSub.subscribe("test-topic")
    end
  end

  describe "broadcast/4 without pubsub configured" do
    test "returns error when no pubsub server" do
      assert {:error, :no_pubsub_configured} =
               PubSub.broadcast("test-topic", :event_created, %{id: "1"})
    end
  end

  describe "broadcast_from/4 without pubsub configured" do
    test "returns error when no pubsub server" do
      assert {:error, :no_pubsub_configured} =
               PubSub.broadcast_from("test-topic", :event_created, %{id: "1"})
    end
  end

  describe "unsubscribe/2 without pubsub configured" do
    test "returns ok even without pubsub" do
      assert :ok = PubSub.unsubscribe("test-topic")
    end
  end
end
