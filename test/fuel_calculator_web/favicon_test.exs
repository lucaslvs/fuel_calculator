defmodule FuelCalculatorWeb.FaviconTest do
  use FuelCalculatorWeb.ConnCase, async: true

  test "pages link the SVG favicon", %{conn: conn} do
    document = conn |> get(~p"/") |> html_response(200) |> LazyHTML.from_document()

    assert document
           |> LazyHTML.query(~s(link[rel="icon"][type="image/svg+xml"][href="/favicon.svg"]))
           |> Enum.count() == 1
  end

  test "GET /favicon.svg serves the icon", %{conn: conn} do
    conn = get(conn, "/favicon.svg")

    assert conn.status == 200
    assert conn |> get_resp_header("content-type") |> hd() =~ "image/svg+xml"
  end
end
