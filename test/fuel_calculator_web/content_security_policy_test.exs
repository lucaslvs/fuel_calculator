defmodule FuelCalculatorWeb.ContentSecurityPolicyTest do
  use FuelCalculatorWeb.ConnCase, async: true

  test "GET / sends a strict content security policy", %{conn: conn} do
    conn = get(conn, ~p"/")
    policy = policy(conn)
    # The port comes from the PORT environment variable when it is set
    %URI{host: host, port: port} = FuelCalculatorWeb.Endpoint.struct_url()

    assert policy == %{
             "default-src" => ["'self'"],
             "script-src" => ["'self'"],
             "style-src" => ["'self'"],
             "img-src" => ["'self'", "data:"],
             "connect-src" => ["'self'", "ws://#{host}:#{port}"],
             "object-src" => ["'none'"],
             "base-uri" => ["'self'"],
             "form-action" => ["'self'"],
             "frame-ancestors" => ["'none'"]
           }
  end

  # The policy blocks inline scripts
  test "pages have no inline scripts", %{conn: conn} do
    inline_scripts =
      conn
      |> get(~p"/")
      |> html_response(200)
      |> LazyHTML.from_document()
      |> LazyHTML.query("script:not([src])")

    assert Enum.empty?(inline_scripts)
  end

  defp policy(conn) do
    [header] = get_resp_header(conn, "content-security-policy")

    for directive <- String.split(header, ";", trim: true), into: %{} do
      [name | sources] = String.split(directive)
      {name, sources}
    end
  end
end
