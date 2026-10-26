# The browser tests (FuelCalculatorWeb.BrowserCase, tagged :e2e) need Node,
# Playwright's Chromium and the endpoint's server, so they only run with
# `mix test.browser`
ExUnit.start(exclude: [:e2e])

if :e2e in ExUnit.configuration()[:include] do
  FuelCalculatorWeb.Endpoint.config(:server) ||
    raise "the browser tests need the endpoint's server: run them with mix test.browser"

  {:ok, _} = PhoenixTest.Playwright.Supervisor.start_link()
  Application.put_env(:phoenix_test, :base_url, FuelCalculatorWeb.Endpoint.url())
end
