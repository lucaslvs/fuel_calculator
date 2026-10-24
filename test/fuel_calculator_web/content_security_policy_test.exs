defmodule FuelCalculatorWeb.ContentSecurityPolicyTest do
  use FuelCalculatorWeb.ConnCase, async: true

  test "GET / sends a strict content security policy", %{conn: conn} do
    conn = get(conn, ~p"/")
    policy = policy(conn)
    nonce = nonce(policy)
    # The port comes from the PORT environment variable when it is set
    %URI{host: host, port: port} = FuelCalculatorWeb.Endpoint.struct_url()

    assert policy == %{
             "default-src" => ["'self'"],
             "script-src" => ["'self'", "'nonce-#{nonce}'"],
             "style-src" => ["'self'"],
             "img-src" => ["'self'", "data:"],
             "connect-src" => ["'self'", "ws://#{host}:#{port}"],
             "object-src" => ["'none'"],
             "base-uri" => ["'self'"],
             "form-action" => ["'self'"],
             "frame-ancestors" => ["'none'"]
           }
  end

  test "every inline script carries the policy's nonce", %{conn: conn} do
    conn = get(conn, ~p"/")
    nonce = conn |> policy() |> nonce()

    inline_scripts =
      conn
      |> html_response(200)
      |> LazyHTML.from_document()
      |> LazyHTML.query("script:not([src])")

    refute Enum.empty?(inline_scripts)
    assert LazyHTML.attribute(inline_scripts, "nonce") |> Enum.uniq() == [nonce]
  end

  test "each request gets a new nonce", %{conn: conn} do
    first = conn |> get(~p"/") |> policy() |> nonce()
    second = build_conn() |> get(~p"/") |> policy() |> nonce()

    refute first == second
  end

  defp policy(conn) do
    [header] = get_resp_header(conn, "content-security-policy")

    for directive <- String.split(header, ";", trim: true), into: %{} do
      [name | sources] = String.split(directive)
      {name, sources}
    end
  end

  defp nonce(policy) do
    policy
    |> Map.get("script-src", [])
    |> Enum.find_value(fn source ->
      case Regex.run(~r/^'nonce-(.+)'$/, source) do
        [_, nonce] -> nonce
        nil -> nil
      end
    end)
  end
end
