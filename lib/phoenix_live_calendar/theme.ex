defmodule PhoenixLiveCalendar.Theme do
  @moduledoc """
  Resolves semantic color tokens to concrete class pairs, so the data layer
  can say `:primary` or `"brand"` instead of hardcoding Tailwind strings.

  `Event.color` and `Layer.color` accept, in priority order:

  1. **Semantic tokens** — the eight daisyUI semantics as atoms
     (`:primary`, `:secondary`, `:accent`, `:neutral`, `:info`, `:success`,
     `:warning`, `:error`), each resolving to its `bg-*`/`text-*-content`
     pair.
  2. **App-defined tokens** — configured once per host:

         config :phoenix_live_calendar, :color_tokens, %{
           "brand" => {"bg-[#5b21b6]", "text-white"},
           :muted => "bg-base-300"
         }

     Values are a `{bg, text}` pair or a bare bg class (text is then
     inferred). Keys match exactly (atom or string).
  3. **Raw class strings** — pass through unchanged, exactly as before.

  An atom that matches neither a semantic nor a configured token resolves
  to `nil` (the views fall back to their default color).

  As with every class in this library, resolved classes must be complete
  names the host's Tailwind build can see.
  """

  alias PhoenixLiveCalendar.Event
  alias PhoenixLiveCalendar.Utils.Safe

  @semantic %{
    primary: {"bg-primary", "text-primary-content"},
    secondary: {"bg-secondary", "text-secondary-content"},
    accent: {"bg-accent", "text-accent-content"},
    neutral: {"bg-neutral", "text-neutral-content"},
    info: {"bg-info", "text-info-content"},
    success: {"bg-success", "text-success-content"},
    warning: {"bg-warning", "text-warning-content"},
    error: {"bg-error", "text-error-content"}
  }

  @doc "The built-in semantic token atoms."
  @spec semantic_tokens() :: [atom()]
  def semantic_tokens, do: Map.keys(@semantic)

  @doc """
  Resolves a color value to a `{bg_class, text_class | nil}` pair, or `nil`
  when there is nothing to apply (nil input or an unknown atom token).
  """
  @spec resolve(atom() | String.t() | nil) :: {String.t(), String.t() | nil} | nil
  def resolve(nil), do: nil

  def resolve(color) when is_map_key(@semantic, color), do: @semantic[color]

  def resolve(color) do
    case Map.get(custom_tokens(), color) do
      {bg, text} when is_binary(bg) -> {bg, text}
      bg when is_binary(bg) -> {bg, nil}
      nil when is_binary(color) -> {color, nil}
      _ -> nil
    end
  end

  @doc "The resolved background class for a color value, or `nil`."
  @spec bg(atom() | String.t() | nil) :: String.t() | nil
  def bg(color) do
    case resolve(color) do
      {bg, _text} -> bg
      nil -> nil
    end
  end

  @doc """
  The `{bg_class, text_class}` an event renders with: the event's resolved
  `color` (or `default_bg` when it has none), and its explicit `text_color`,
  falling back to the token pair's text, falling back to inferring from the
  APPLIED background.

  This is the single merge rule for every event render path.
  """
  @spec event_colors(Event.t(), String.t()) :: {String.t(), String.t()}
  def event_colors(%Event{} = event, default_bg \\ "bg-primary") do
    {bg, pair_text} =
      case resolve(event.color) do
        {bg, text} -> {bg, text}
        nil -> {nil, nil}
      end

    bg = bg || default_bg
    text = event.text_color || pair_text || Safe.infer_text_color(bg)
    {bg, text}
  end

  @doc """
  `event_colors/2` as a class list — the one-liner every bar render uses.
  """
  @spec event_color_classes(Event.t(), String.t()) :: [String.t()]
  def event_color_classes(%Event{} = event, default_bg \\ "bg-primary") do
    {bg, text} = event_colors(event, default_bg)
    [bg, text]
  end

  defp custom_tokens do
    Application.get_env(:phoenix_live_calendar, :color_tokens, %{})
  end
end
