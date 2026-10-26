defmodule FuelCalculatorWeb.Browser.MassTest do
  use FuelCalculatorWeb.BrowserCase, async: true

  test "groups the digits while typing", %{conn: conn} do
    conn
    |> type("#mission_mass", "28801")
    |> assert_has("#mission_mass", value: "28,801")
    # The server's answer: before it, the refute_has below would pass for any mass
    |> assert_has("#fuel-pending", text: "Add the first step")
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
