defmodule FuelCalculatorWeb.Browser.FlightPathTest do
  use FuelCalculatorWeb.BrowserCase, async: true

  setup %{conn: conn} do
    conn =
      conn
      |> fill_in("#mission_mass", "Spacecraft mass", with: "28,801", exact: false)
      |> assert_has("#add-step")

    %{conn: conn}
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
