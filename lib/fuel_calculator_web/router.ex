defmodule FuelCalculatorWeb.Router do
  use FuelCalculatorWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {FuelCalculatorWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :put_content_security_policy
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", FuelCalculatorWeb do
    pipe_through :browser

    live "/", MissionLive
  end

  # Other scopes may use custom stacks.
  # scope "/api", FuelCalculatorWeb do
  #   pipe_through :api
  # end

  if Application.compile_env(:fuel_calculator, :strict_csp, true) do
    # The pages have no inline scripts, so scripts only come from the app's origin
    defp put_content_security_policy(conn, _opts) do
      url = FuelCalculatorWeb.Endpoint.struct_url()
      websocket = URI.to_string(%{url | scheme: if(url.scheme == "https", do: "wss", else: "ws")})

      policy =
        Enum.join(
          [
            "default-src 'self'",
            "script-src 'self'",
            "style-src 'self'",
            # The hero icons are CSS masks with data: URLs
            "img-src 'self' data:",
            # Some browsers don't match WebSockets with 'self'
            "connect-src 'self' #{websocket}",
            "object-src 'none'",
            "base-uri 'self'",
            "form-action 'self'",
            "frame-ancestors 'none'"
          ],
          "; "
        )

      put_resp_header(conn, "content-security-policy", policy)
    end
  else
    defp put_content_security_policy(conn, _opts), do: conn
  end
end
