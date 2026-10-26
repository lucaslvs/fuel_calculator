defmodule FuelCalculatorWeb.Browser.FlightPathTest do
  use FuelCalculatorWeb.BrowserCase, async: true

  alias PlaywrightEx.Selector

  setup %{conn: conn} do
    conn =
      conn
      |> fill_in("#mission_mass", "Spacecraft mass", with: "28,801", exact: false)
      |> assert_has("#add-step")

    %{conn: conn}
  end

  test "adds and removes a step with the keyboard alone", %{conn: conn} do
    conn
    |> press("#mission_mass", "Tab")
    |> assert_has("#add-step:focus")
    |> press("#add-step", "Enter")
    |> assert_has("#add-step-launch:focus")
    |> refute_has("#add-step")
    |> press("#add-step-launch", "Escape")
    |> assert_has("#add-step:focus")
    |> refute_has("#add-step-actions")
    |> press("#add-step", "Enter")
    |> press("#add-step-launch", "Tab")
    |> press(Selector.role("button", "Land", exact: true), "Enter")
    |> assert_has("#mission_steps_0_action_land:checked")
    |> assert_has("#mission_steps_0_planet:focus")
    |> select("Step 1 planet", option: "Earth")
    |> assert_has("#total-fuel", text: "13,447 kg")
    |> press(Selector.role("button", "Remove step 1", exact: true), "Enter")
    |> refute_has("#step-0")
    |> assert_has("#add-step:focus")
  end

  test "focuses the mass after removing the only step, when Add step is gone", %{conn: conn} do
    conn
    |> click_button("Add step")
    |> click_button("Launch")
    |> assert_has("#mission_steps_0_planet:focus")
    |> refute_has("#add-step")
    |> click_button("Remove step 1")
    |> refute_has("#step-0")
    |> assert_has("#mission_mass:focus")
  end

  test "keeps the focus in place of a removed step", %{conn: conn} do
    conn
    |> click_button("#example-apollo-11", "Apollo 11")
    |> press(Selector.role("button", "Remove step 4", exact: true), "Enter")
    |> refute_has("#step-3")
    |> assert_has("#remove-step-2:focus")
    # The next step's button takes the place of the first
    |> press(Selector.role("button", "Remove step 1", exact: true), "Enter")
    |> assert_has("#step-0 [data-role=step-title]", text: "1 · Land on the Moon")
    |> assert_has("#remove-step-0:focus")
  end

  test "closes the actions on a click elsewhere", %{conn: conn} do
    conn
    |> click_button("Add step")
    |> assert_has("#add-step-launch:focus")
    |> click("h1")
    |> refute_has("#add-step-actions")
    |> assert_has("#add-step")
  end

  test "opens the actions on a double click on Add step", %{conn: conn} do
    conn
    # On the label, where Launch takes its place after the first click
    |> double_click("#add-step", %{x: 30, y: 26})
    |> assert_has("#add-step-launch:focus")
    |> evaluate(
      """
      (() => {
        const {left, top} = document.getElementById("add-step-actions").getBoundingClientRect()
        return document.elementFromPoint(left + 30, top + 26).closest("#add-step-launch") !== null
      })()
      """,
      &assert(&1, "the second click didn't land on Launch, so it tests nothing")
    )
    |> click_button("#add-step-land", "Land")
    |> assert_has("#mission_steps_0_action_land:checked")
  end

  test "closes the actions when the focus leaves them", %{conn: conn} do
    conn
    |> press("#add-step", "Enter")
    |> assert_has("#add-step-launch:focus")
    |> press("#add-step-launch", "Tab")
    |> assert_has("#add-step-land:focus")
    |> assert_has("#add-step-actions")
    |> press("#add-step-land", "Shift+Tab")
    |> press("#add-step-launch", "Shift+Tab")
    |> assert_has("#mission_mass:focus")
    |> refute_has("#add-step-actions")
    |> assert_has("#add-step")
  end

  defp double_click(conn, selector, position) do
    unwrap(conn, fn %{frame_id: frame_id} ->
      {:ok, _} =
        PlaywrightEx.Frame.click(frame_id,
          selector: selector,
          position: position,
          click_count: 2,
          timeout: timeout()
        )
    end)
  end
end
