defmodule Mix.Tasks.PhoenixLiveCalendar.InstallTest do
  # async: false + @tag :tmp_dir — swaps the global Mix.shell and writes fixture files.
  use ExUnit.Case, async: false

  @task Mix.Tasks.PhoenixLiveCalendar.Install

  setup do
    Mix.shell(Mix.Shell.Process)
    on_exit(fn -> Mix.shell(Mix.Shell.IO) end)
    :ok
  end

  defp shell_output do
    receive do
      {:mix_shell, :info, [msg]} -> msg <> "\n" <> shell_output()
    after
      0 -> ""
    end
  end

  @tag :tmp_dir
  test "injects the CSS @source and the JS import + hooks into a fresh project", %{tmp_dir: tmp} do
    css = Path.join(tmp, "app.css")
    js = Path.join(tmp, "app.js")
    File.write!(css, ~s|@import "tailwindcss";\n@source "../js";\n|)

    File.write!(
      js,
      ~s|import "phoenix_html"\nimport {LiveSocket} from "phoenix_live_view"\nlet liveSocket = new LiveSocket("/live", Socket, {hooks: {}})\n|
    )

    @task.run(["--css-path", css, "--js-path", js])

    css_out = File.read!(css)
    assert css_out =~ "PhoenixLiveCalendar CSS Integration"
    assert css_out =~ ~s(@source "../../deps/phoenix_live_calendar")

    js_out = File.read!(js)
    assert js_out =~ "PhoenixLiveCalendar JS hooks"
    assert js_out =~ "deps/phoenix_live_calendar/priv/static/assets/phoenix_live_calendar.js"
    assert js_out =~ "...window.PhoenixLiveCalendarHooks"
  end

  @tag :tmp_dir
  test "is idempotent — a second run makes no further changes", %{tmp_dir: tmp} do
    css = Path.join(tmp, "app.css")
    js = Path.join(tmp, "app.js")
    File.write!(css, ~s|@import "tailwindcss";\n|)

    File.write!(
      js,
      ~s|import {LiveSocket} from "phoenix_live_view"\nlet liveSocket = new LiveSocket("/live", Socket, {hooks: {}})\n|
    )

    @task.run(["--css-path", css, "--js-path", js])
    css_once = File.read!(css)
    js_once = File.read!(js)

    @task.run(["--css-path", css, "--js-path", js])
    assert File.read!(css) == css_once
    assert File.read!(js) == js_once
    assert shell_output() =~ "already configured"
  end

  @tag :tmp_dir
  test "leaves hooks wiring to the user when it can't be done safely", %{tmp_dir: tmp} do
    js = Path.join(tmp, "app.js")
    # `hooks: Hooks` is not a literal object → wire_hooks must not touch it.
    File.write!(
      js,
      ~s|import {LiveSocket} from "phoenix_live_view"\nlet liveSocket = new LiveSocket("/live", Socket, {hooks: Hooks})\n|
    )

    @task.run(["--js-path", js])

    js_out = File.read!(js)
    assert js_out =~ "phoenix_live_calendar.js"
    refute js_out =~ "...window.PhoenixLiveCalendarHooks"
    assert shell_output() =~ "hooks"
  end

  @tag :tmp_dir
  test "prints manual instructions when no css/js file is found", %{tmp_dir: tmp} do
    @task.run([
      "--css-path",
      Path.join(tmp, "missing.css"),
      "--js-path",
      Path.join(tmp, "missing.js")
    ])

    out = shell_output()
    assert out =~ "Could not find app.css"
    assert out =~ ~s(@source "../../deps/phoenix_live_calendar")
    assert out =~ "Could not find app.js"
    assert out =~ "...window.PhoenixLiveCalendarHooks"
  end
end
