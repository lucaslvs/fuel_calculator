defmodule FuelCalculatorWeb.Browser.PhoneTest do
  # Below lg the fuel summary is a bar fixed to the bottom of the screen
  use FuelCalculatorWeb.BrowserCase,
    async: true,
    browser_context_opts: [viewport: %{width: 375, height: 667}, reduced_motion: "reduce"]

  test "opens the fuel by step from the bar and keeps it open", %{conn: conn} do
    conn
    |> click_button("#example-apollo-11", "Apollo 11")
    |> assert_has("#loaded-example")
    |> refute_has("#fuel-by-step")
    |> click("#fuel-by-step-toggle")
    |> assert_has("#fuel-by-step-toggle[aria-expanded=true]")
    |> assert_has("#fuel-by-step li", count: 4)
    |> fill_in("#mission_mass", "Spacecraft mass", with: "28,802", exact: false)
    |> refute_has("#loaded-example")
    |> assert_has("#fuel-by-step li", count: 4)
    |> click("#fuel-by-step-toggle")
    |> assert_has("#fuel-by-step-toggle[aria-expanded=false]")
    |> refute_has("#fuel-by-step")
  end

  test "keeps a new step clear of the bar", %{conn: conn} do
    conn
    |> click_button("#example-apollo-11", "Apollo 11")
    |> click_button("Add step")
    |> click_button("Land")
    |> assert_has("#mission_steps_4_planet:focus")
    |> evaluate(
      """
      (() => {
        const bar = document.getElementById("fuel-summary").getBoundingClientRect()
        const field = document.activeElement.getBoundingClientRect()
        const overflow = document.documentElement.scrollWidth > window.innerWidth
        return {covered: field.bottom > bar.top, overflow}
      })()
      """,
      &assert(&1 == %{"covered" => false, "overflow" => false})
    )
  end
end
