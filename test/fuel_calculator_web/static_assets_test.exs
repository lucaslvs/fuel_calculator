defmodule FuelCalculatorWeb.StaticAssetsTest do
  use FuelCalculatorWeb.ConnCase, async: true

  @css_urls ~r{url\("(/[^"]+)"\)}

  test "pages preload the body font", %{conn: conn} do
    document = conn |> get(~p"/") |> html_response(200) |> LazyHTML.from_document()

    selector =
      ~s(link[rel="preload"][as="font"][type="font/woff2"][crossorigin]) <>
        ~s([href="/fonts/ibm-plex-sans-latin-wght-normal.woff2"])

    assert document |> LazyHTML.query(selector) |> Enum.count() == 1
  end

  # The CSP only allows fonts and images from the app's own origin
  test "serves every font and image the CSS asks for", %{conn: conn} do
    paths =
      @css_urls
      |> Regex.scan(File.read!("assets/css/app.css"), capture: :all_but_first)
      |> List.flatten()
      |> Enum.uniq()

    assert Enum.count(paths, &String.starts_with?(&1, "/fonts/")) == 1
    assert Enum.count(paths, &String.starts_with?(&1, "/images/")) == 4

    for path <- paths do
      conn = get(conn, path)

      assert conn.status == 200
      assert conn |> get_resp_header("content-type") |> hd() =~ content_type(path)
    end
  end

  defp content_type("/fonts/" <> _), do: "font/woff2"
  defp content_type("/images/" <> _), do: "image/svg+xml"
end
