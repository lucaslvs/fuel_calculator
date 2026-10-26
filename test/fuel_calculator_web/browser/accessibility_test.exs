defmodule FuelCalculatorWeb.Browser.AccessibilityTest do
  use FuelCalculatorWeb.BrowserCase, async: true

  @phone [viewport: %{width: 375, height: 667}, reduced_motion: "reduce"]

  test "has no accessibility violations in its main states", %{conn: conn} do
    conn
    |> assert_accessible()
    |> click_button("#example-mars", "Mars mission")
    |> select("Step 2 planet", option: "Earth")
    |> assert_has("#fix-step-2")
    |> click("#step-details-0 summary")
    |> click_button("Add step")
    |> assert_has("#add-step-launch:focus")
    |> assert_accessible()
  end

  @tag browser_context_opts: @phone
  test "has no accessibility violations on a phone", %{conn: conn} do
    conn
    |> press("#mission_mass", "Enter")
    |> assert_has("#mission_mass-error")
    |> assert_accessible()
    |> click_button("#example-apollo-11", "Apollo 11")
    |> click("#fuel-by-step-toggle")
    |> assert_has("#fuel-by-step")
    |> assert_accessible()
  end

  # WCAG 2.2 A and AA, and axe's best practices. The page's security policy blocks a
  # script tag, not evaluate. Read when the test runs: `mix test` compiles this file
  # too, where node_modules may not exist.
  defp assert_accessible(conn) do
    conn
    # Phoenix's progress bar, a canvas outside the page's landmarks, shows while a slow
    # load lasts
    |> refute_has("body > canvas")
    |> evaluate(File.read!("test/browser/node_modules/axe-core/axe.min.js"))
    |> evaluate(
      """
      axe.run(document, {
        runOnly: ["wcag2a", "wcag2aa", "wcag21a", "wcag21aa", "wcag22aa", "best-practice"]
      }).then(({violations}) => violations.map(v =>
        `${v.id} (${v.impact}): ${v.help}\\n  ${v.nodes.map(n => n.target.join(" ")).join("\\n  ")}`
      ))
      """,
      &assert(&1 == [], Enum.join(&1, "\n"))
    )
  end
end
