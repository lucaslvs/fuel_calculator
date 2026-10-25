defmodule FuelCalculatorWeb.ErrorHTMLTest do
  use FuelCalculatorWeb.ConnCase, async: true

  # Bring render_to_string/4 for testing custom views
  import Phoenix.Template, only: [render_to_string: 4]

  test "a missing page shows the 404 page with a way home", %{conn: conn} do
    page = conn |> get("/nowhere") |> html_response(404) |> LazyHTML.from_document()

    assert text(page, "#error h1") == "Page not found"
    assert page |> LazyHTML.query("#go-home") |> LazyHTML.attribute("href") == ["/"]
    assert page |> LazyHTML.query("link[rel=stylesheet]") |> Enum.count() == 1
    assert page |> LazyHTML.query("script") |> Enum.empty?()
  end

  test "renders 500.html" do
    page =
      FuelCalculatorWeb.ErrorHTML
      |> render_to_string("500", "html", [])
      |> LazyHTML.from_document()

    assert text(page, "#error h1") == "Something went wrong"
    assert page |> LazyHTML.query("#go-home") |> LazyHTML.attribute("href") == ["/"]
  end

  test "renders other errors as their status message" do
    assert render_to_string(FuelCalculatorWeb.ErrorHTML, "413", "html", []) ==
             "Request Entity Too Large"
  end

  defp text(page, selector), do: page |> LazyHTML.query(selector) |> LazyHTML.text()
end
