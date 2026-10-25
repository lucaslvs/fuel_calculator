defmodule FuelCalculatorWeb.FontsTest do
  use FuelCalculatorWeb.ConnCase, async: true

  @css_fonts ~r{url\("(/fonts/[^"]+)"\)}

  test "pages preload the body font", %{conn: conn} do
    document = conn |> get(~p"/") |> html_response(200) |> LazyHTML.from_document()

    selector =
      ~s(link[rel="preload"][as="font"][type="font/woff2"][crossorigin]) <>
        ~s([href="/fonts/ibm-plex-sans-latin-wght-normal.woff2"])

    assert document |> LazyHTML.query(selector) |> Enum.count() == 1
  end

  # The CSP only allows fonts from the app's own origin
  test "serves every font the CSS asks for", %{conn: conn} do
    paths =
      @css_fonts
      |> Regex.scan(File.read!("assets/css/app.css"), capture: :all_but_first)
      |> List.flatten()

    assert length(paths) == 4

    for path <- paths do
      conn = get(conn, path)

      assert conn.status == 200
      assert conn |> get_resp_header("content-type") |> hd() =~ "font/woff2"
    end
  end
end
