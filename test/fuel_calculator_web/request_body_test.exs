defmodule FuelCalculatorWeb.RequestBodyTest do
  use FuelCalculatorWeb.ConnCase, async: true

  # No route takes a request body
  test "a body other than a form isn't read", %{conn: conn} do
    conn = put_req_header(conn, "content-type", "multipart/form-data; boundary=none")

    assert conn |> post("/upload", "not a multipart body") |> response(404)
  end

  test "a form body is limited to 64 KB", %{conn: conn} do
    conn = put_req_header(conn, "content-type", "application/x-www-form-urlencoded")

    assert_error_sent 413, fn -> post(conn, "/", "a=" <> String.duplicate("x", 65_536)) end
  end
end
