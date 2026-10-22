defmodule FuelCalculatorWeb.FaviconTest do
  use FuelCalculatorWeb.ConnCase, async: true

  test "pages link the SVG favicon", %{conn: conn} do
    document = conn |> get(~p"/") |> html_response(200) |> LazyHTML.from_document()

    assert document
           |> LazyHTML.query(~s(link[rel="icon"][type="image/svg+xml"][href="/favicon.svg"]))
           |> Enum.count() == 1
  end

  # In production the link points to the digested copy, favicon-<hash>.svg
  test "GET /favicon-<hash>.svg serves the digested icon", %{conn: conn} do
    name = "favicon-#{System.unique_integer([:positive])}.svg"
    path = Application.app_dir(:fuel_calculator, ["priv", "static", name])
    File.cp!(Application.app_dir(:fuel_calculator, "priv/static/favicon.svg"), path)
    on_exit(fn -> File.rm(path) end)

    conn = get(conn, "/" <> name)

    assert conn.status == 200
    assert conn |> get_resp_header("content-type") |> hd() =~ "image/svg+xml"
  end

  test "GET /favicon.svg serves the icon", %{conn: conn} do
    conn = get(conn, "/favicon.svg")

    assert conn.status == 200
    assert conn |> get_resp_header("content-type") |> hd() =~ "image/svg+xml"
  end
end
