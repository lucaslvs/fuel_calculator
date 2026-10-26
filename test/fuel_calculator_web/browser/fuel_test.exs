defmodule FuelCalculatorWeb.Browser.FuelTest do
  use FuelCalculatorWeb.BrowserCase, async: true

  test "keeps an open explanation open while the mass changes", %{conn: conn} do
    conn
    |> click_button("#example-apollo-11", "Apollo 11")
    |> click("#step-details-3 summary")
    |> assert_has("#step-details-3 [data-role=iterations]", text: "= 13,447 kg")
    |> fill_in("#mission_mass", "Spacecraft mass", with: "14,606", exact: false)
    |> refute_has("#step-details-3 summary", text: "How 13,447 kg")
    |> assert_has("#step-details-3 [data-role=iterations]")
  end
end
