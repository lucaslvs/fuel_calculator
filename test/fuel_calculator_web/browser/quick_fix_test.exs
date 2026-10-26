defmodule FuelCalculatorWeb.Browser.QuickFixTest do
  use FuelCalculatorWeb.BrowserCase, async: true

  test "shows the planet the fuel is calculated with", %{conn: conn} do
    conn
    |> click_button("#example-mars", "Mars mission")
    |> select("Step 2 planet", option: "Earth")
    |> click_button("#fix-step-2", "Launch from Earth instead")
    |> assert_has("#step-2 [data-role=step-title]", text: "3 · Launch from Earth")
    |> assert_has("#mission_steps_2_planet:focus")
    |> assert_has("#mission_steps_2_planet", selected: "Earth")
    # The next change sends the form as the page shows it
    |> fill_in("#mission_mass", "Spacecraft mass", with: "14,607", exact: false)
    |> assert_has("#mission_mass", value: "14,607")
    |> assert_has("#step-2 [data-role=step-title]", text: "3 · Launch from Earth")
    |> assert_has("#mission_steps_2_planet", selected: "Earth")
  end

  test "focuses the action it changes", %{conn: conn} do
    conn
    |> click_button("#example-mars", "Mars mission")
    |> click("#step-2 label", "Land", exact: true)
    |> click_button("#fix-step-2", "Launch from Mars instead")
    |> assert_has("#step-2 [data-role=step-title]", text: "3 · Launch from Mars")
    |> assert_has("#mission_steps_2_action_launch:focus:checked")
  end
end
