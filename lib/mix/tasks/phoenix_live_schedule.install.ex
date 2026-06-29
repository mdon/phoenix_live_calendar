defmodule Mix.Tasks.PhoenixLiveSchedule.Install do
  @shortdoc "Installs PhoenixLiveSchedule in your Phoenix project"

  @moduledoc """
  Installs PhoenixLiveSchedule into your Phoenix project.

      $ mix phoenix_live_schedule.install

  This task:

  1. Finds your `app.css` and adds an `@source` directive so Tailwind scans
     PhoenixLiveSchedule's component templates
  2. Finds your `app.js`, adds the JS hook import, and registers
     `window.PhoenixLiveScheduleHooks` in your LiveSocket when it can do so safely

  Both steps are idempotent — safe to run multiple times. When the task can't
  edit a file automatically it prints exact manual instructions instead of
  guessing.

  ## Options

  - `--css-path` — Path to your app.css file (auto-detected if not specified)
  - `--js-path` — Path to your app.js file (auto-detected if not specified)
  """

  use Mix.Task

  @css_marker "/* PhoenixLiveSchedule CSS Integration */"
  @source_line ~s(@source "../../deps/phoenix_live_schedule";)

  @js_marker "// PhoenixLiveSchedule JS hooks"
  @js_import ~s(import "../../deps/phoenix_live_schedule/priv/static/assets/phoenix_live_schedule.js")
  @hooks_snippet "hooks: { ...window.PhoenixLiveScheduleHooks, ...yourHooks }"

  @css_paths [
    "assets/css/app.css",
    "priv/static/assets/app.css",
    "assets/app.css"
  ]

  @js_paths [
    "assets/js/app.js",
    "assets/app.js"
  ]

  @impl true
  def run(args) do
    {opts, _, _} = OptionParser.parse(args, strict: [css_path: :string, js_path: :string])

    Mix.shell().info("\n  PhoenixLiveSchedule Install\n")

    case find_path(opts[:css_path], @css_paths) do
      {:ok, path} -> integrate_css(path)
      {:error, :not_found} -> print_manual_css_instructions()
    end

    case find_path(opts[:js_path], @js_paths) do
      {:ok, path} -> integrate_js(path)
      {:error, :not_found} -> print_manual_js_instructions()
    end

    Mix.shell().info("")
  end

  defp find_path(nil, candidates) do
    case Enum.find(candidates, &File.exists?/1) do
      nil -> {:error, :not_found}
      path -> {:ok, path}
    end
  end

  defp find_path(path, _candidates) do
    if File.exists?(path), do: {:ok, path}, else: {:error, :not_found}
  end

  # -- CSS --

  defp integrate_css(path) do
    content = File.read!(path)

    cond do
      String.contains?(content, @css_marker) ->
        Mix.shell().info("  CSS already configured in #{path}")

      String.contains?(content, "phoenix_live_schedule") ->
        Mix.shell().info("  PhoenixLiveSchedule source already present in #{path}")

      true ->
        File.write!(path, inject_source(content))
        Mix.shell().info("  Added PhoenixLiveSchedule source to #{path}")
    end
  end

  defp inject_source(content) do
    lines = String.split(content, "\n")
    {before, after_lines} = css_insertion_point(lines)
    insertion = "\n#{@css_marker}\n#{@source_line}\n"
    Enum.join(before, "\n") <> insertion <> Enum.join(after_lines, "\n")
  end

  defp css_insertion_point(lines) do
    last_source_idx =
      lines
      |> Enum.with_index()
      |> Enum.filter(fn {line, _idx} -> String.starts_with?(String.trim(line), "@source") end)
      |> List.last()

    case last_source_idx do
      {_line, idx} -> Enum.split(lines, idx + 1)
      nil -> css_fallback_point(lines)
    end
  end

  defp css_fallback_point(lines) do
    import_idx =
      lines
      |> Enum.with_index()
      |> Enum.find(fn {line, _} -> String.contains?(line, "tailwindcss") end)

    case import_idx do
      {_line, idx} -> Enum.split(lines, idx + 1)
      nil -> {[], lines}
    end
  end

  # -- JS --

  defp integrate_js(path) do
    content = File.read!(path)

    cond do
      String.contains?(content, @js_marker) ->
        Mix.shell().info("  JS already configured in #{path}")

      String.contains?(content, "phoenix_live_schedule") ->
        Mix.shell().info("  PhoenixLiveSchedule JS import already present in #{path}")
        unless String.contains?(content, "PhoenixLiveScheduleHooks"), do: print_hooks_instructions()

      true ->
        {new_content, hooks_wired?} = content |> inject_js_import() |> wire_hooks()
        File.write!(path, new_content)
        Mix.shell().info("  Added PhoenixLiveSchedule JS import to #{path}")
        report_hooks_result(hooks_wired?)
    end
  end

  defp inject_js_import(content) do
    lines = String.split(content, "\n")
    {before, after_lines} = Enum.split(lines, js_insertion_index(lines))
    Enum.join(before ++ [@js_marker, @js_import] ++ after_lines, "\n")
  end

  # Insert right after the last top-level `import` line so the hooks global is
  # defined before the LiveSocket is constructed; fall back to the top.
  defp js_insertion_index(lines) do
    lines
    |> Enum.with_index()
    |> Enum.filter(fn {line, _idx} -> String.starts_with?(String.trim(line), "import ") end)
    |> List.last()
    |> case do
      {_line, idx} -> idx + 1
      nil -> 0
    end
  end

  # Only spread the hooks automatically when there's exactly one `hooks: {`
  # object literal — anything else (e.g. `hooks: Hooks`) is left for the user
  # so we never corrupt their app.js.
  defp wire_hooks(content) do
    cond do
      String.contains?(content, "PhoenixLiveScheduleHooks") ->
        {content, true}

      count(content, "hooks: {") == 1 ->
        {String.replace(content, "hooks: {", "hooks: { ...window.PhoenixLiveScheduleHooks, ",
           global: false
         ), true}

      true ->
        {content, false}
    end
  end

  defp count(content, substr), do: length(String.split(content, substr)) - 1

  defp report_hooks_result(true),
    do: Mix.shell().info("  Registered window.PhoenixLiveScheduleHooks in your LiveSocket")

  defp report_hooks_result(false), do: print_hooks_instructions()

  # -- Manual instructions --

  defp print_manual_css_instructions do
    Mix.shell().info("""
      Could not find app.css automatically.

      Add this line to your CSS file (after other @source directives):

          #{@source_line}

      Or run with --css-path:

          mix phoenix_live_schedule.install --css-path assets/css/app.css
    """)
  end

  defp print_manual_js_instructions do
    Mix.shell().info("""

      Could not find app.js automatically. Add to your assets/js/app.js:

          #{@js_import}

      Then register the hooks in your LiveSocket:

          let liveSocket = new LiveSocket("/live", Socket, {
            #{@hooks_snippet}
          })

      Or run with --js-path:

          mix phoenix_live_schedule.install --js-path assets/js/app.js
    """)
  end

  defp print_hooks_instructions do
    Mix.shell().info("""

      One more step — register the hooks in your LiveSocket (assets/js/app.js):

          let liveSocket = new LiveSocket("/live", Socket, {
            #{@hooks_snippet}
          })
    """)
  end
end
