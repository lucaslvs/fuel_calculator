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

  # Enable LiveDashboard in development
  if Application.compile_env(:fuel_calculator, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: FuelCalculatorWeb.Telemetry
    end
  end

  # The theme script in the root layout is inline, so it runs with the nonce
  defp put_content_security_policy(conn, _opts) do
    nonce = 18 |> :crypto.strong_rand_bytes() |> Base.encode64()

    conn
    |> assign(:csp_nonce, nonce)
    |> put_content_security_policy_header(nonce)
  end

  if Application.compile_env(:fuel_calculator, :strict_csp, true) do
    defp put_content_security_policy_header(conn, nonce) do
      url = FuelCalculatorWeb.Endpoint.struct_url()
      websocket = URI.to_string(%{url | scheme: if(url.scheme == "https", do: "wss", else: "ws")})

      policy =
        Enum.join(
          [
            "default-src 'self'",
            "script-src 'self' 'nonce-#{nonce}'",
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
    defp put_content_security_policy_header(conn, _nonce), do: conn
  end
end
