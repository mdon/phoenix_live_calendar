defmodule Mix.Tasks.PhoenixLiveSchedule.Install do
  @shortdoc "Installs PhoenixLiveSchedule in your Phoenix project"

  @moduledoc """
  Installs PhoenixLiveSchedule into your Phoenix project.

      $ mix phoenix_live_schedule.install

  This task:

  1. Finds your `app.css` file
  2. Adds `@source` directives so Tailwind scans PhoenixLiveSchedule's component templates
  3. Prints instructions for optional JS hook setup

  Safe to run multiple times — skips if already configured.

  ## Options

  - `--css-path` — Path to your app.css file (auto-detected if not specified)
  """

  use Mix.Task

  @css_marker "/* PhoenixLiveSchedule CSS Integration */"
  @source_line ~s(@source "../../deps/phoenix_live_schedule";)

  @css_paths [
    "assets/css/app.css",
    "priv/static/assets/app.css",
    "assets/app.css"
  ]

  @impl true
  def run(args) do
    {opts, _, _} = OptionParser.parse(args, strict: [css_path: :string])

    Mix.shell().info("\n  PhoenixLiveSchedule Install\n")

    case find_css(opts[:css_path]) do
      {:ok, path} -> integrate_css(path)
      {:error, :not_found} -> print_manual_instructions()
    end

    print_js_instructions()
    Mix.shell().info("")
  end

  defp find_css(nil) do
    case Enum.find(@css_paths, &File.exists?/1) do
      nil -> {:error, :not_found}
      path -> {:ok, path}
    end
  end

  defp find_css(path) do
    if File.exists?(path), do: {:ok, path}, else: {:error, :not_found}
  end

  defp integrate_css(path) do
    content = File.read!(path)

    cond do
      String.contains?(content, @css_marker) ->
        Mix.shell().info("  Already configured in #{path}")

      String.contains?(content, "phoenix_live_schedule") ->
        Mix.shell().info("  PhoenixLiveSchedule source already present in #{path}")

      true ->
        new_content = inject_source(content)
        File.write!(path, new_content)
        Mix.shell().info("  Added PhoenixLiveSchedule source to #{path}")
    end
  end

  defp inject_source(content) do
    lines = String.split(content, "\n")
    {before, after_lines} = find_insertion_point(lines)
    insertion = "\n#{@css_marker}\n#{@source_line}\n"
    Enum.join(before, "\n") <> insertion <> Enum.join(after_lines, "\n")
  end

  defp find_insertion_point(lines) do
    # Insert after the last @source line
    last_source_idx =
      lines
      |> Enum.with_index()
      |> Enum.filter(fn {line, _idx} -> String.starts_with?(String.trim(line), "@source") end)
      |> List.last()

    case last_source_idx do
      {_line, idx} ->
        {Enum.take(lines, idx + 1), Enum.drop(lines, idx + 1)}

      nil ->
        # No @source — insert after @import "tailwindcss"
        import_idx =
          lines
          |> Enum.with_index()
          |> Enum.find(fn {line, _} -> String.contains?(line, "tailwindcss") end)

        case import_idx do
          {_line, idx} -> {Enum.take(lines, idx + 1), Enum.drop(lines, idx + 1)}
          nil -> {[], lines}
        end
    end
  end

  defp print_manual_instructions do
    Mix.shell().info("""
      Could not find app.css automatically.

      Add this line to your CSS file (after other @source directives):

          #{@source_line}

      Or run with --css-path:

          mix phoenix_live_schedule.install --css-path assets/css/app.css
    """)
  end

  defp print_js_instructions do
    Mix.shell().info("""

      Optional: JS hooks for drag interactions
      Add to your assets/js/app.js:

          import "../../deps/phoenix_live_schedule/priv/static/assets/phoenix_live_schedule.js"

          let liveSocket = new LiveSocket("/live", Socket, {
            hooks: { ...window.PhoenixLiveScheduleHooks, ...Hooks }
          })

      Skip this if you only need click-based interactions (no drag).
    """)
  end
end
