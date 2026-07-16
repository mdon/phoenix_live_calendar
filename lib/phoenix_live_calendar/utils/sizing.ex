defmodule PhoenixLiveCalendar.Utils.Sizing do
  @moduledoc """
  Server-side size estimation — the substitute for client measurement.

  The views accept CSS dimension strings (`"3rem"`, `"48px"`); layout
  decisions (how many text lines fit a block, whether a label fits a bar)
  need those as numbers. Everything here is an ESTIMATE in rem against the
  16px root default — good enough to pick a content tier, never used for
  actual geometry (the browser still lays out from the real CSS values).
  """

  @px_per_rem 16

  @doc """
  Parses a CSS dimension string to rem. `"3rem"` → `3.0`, `"48px"` → `3.0`.
  Unparseable values (`calc(...)`, percentages) fall back to `default`.
  """
  @spec parse_rem(String.t() | nil, number()) :: float()
  def parse_rem(value, default \\ 3.0)

  def parse_rem(value, default) when is_binary(value) do
    case Float.parse(String.trim(value)) do
      {n, "rem"} -> n
      {n, "px"} -> n / @px_per_rem
      _ -> default * 1.0
    end
  end

  def parse_rem(_value, default), do: default * 1.0

  @doc """
  Estimated rendered width of a text label in rem at `text-xs`
  (~0.45rem per grapheme + padding).
  """
  @spec label_rem(String.t() | nil) :: float()
  def label_rem(nil), do: 0.0

  def label_rem(text) when is_binary(text) do
    0.5 + String.length(text) * 0.45
  end
end
