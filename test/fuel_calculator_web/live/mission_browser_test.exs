defmodule FuelCalculatorWeb.MissionBrowserTest do
  # The page's JS hooks in a real browser, which LiveViewTest doesn't run. Run with
  # `mix test.browser`.
  use PhoenixTest.Playwright.Case, async: true
  use FuelCalculatorWeb, :verified_routes

  @moduletag :e2e

  setup %{conn: conn} do
    %{conn: conn |> visit(~p"/") |> assert_has("[data-phx-main].phx-connected")}
  end

  describe "quick fix" do
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
      |> click("label[for=mission_steps_2_action_land]")
      |> click_button("#fix-step-2", "Launch from Mars instead")
      |> assert_has("#step-2 [data-role=step-title]", text: "3 · Launch from Mars")
      |> assert_has("#mission_steps_2_action_launch:focus:checked")
    end
  end

  describe "mass" do
    test "groups the digits while typing", %{conn: conn} do
      conn
      |> type("#mission_mass", "28801")
      |> assert_has("#mission_mass", value: "28,801")
      |> refute_has("#mission_mass-error")
    end

    for {typed, shown, error} <- [
          {"-28801", "-28801", "must be greater than 0"},
          {"28801.5", "28,801.5", "must be a whole number"}
        ] do
      test "keeps #{typed} as typed and rejects it", %{conn: conn} do
        conn
        |> type("#mission_mass", unquote(typed))
        |> assert_has("#mission_mass", value: unquote(shown))
        |> assert_has("#mission_mass-error", text: unquote(error))
      end
    end
  end
end
