import Config

# The server only runs for the browser tests: `mix test.browser` sets PHX_SERVER
# (see runtime.exs)
config :fuel_calculator, FuelCalculatorWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "6j5eL2XroTB9VDYJU0lup7mV+NyFeGVW3howf6gXvZhHsIgorKN4CR7/WlFeEN+7",
  server: false

# Playwright is installed in test/browser, out of assets/, where Gigalixir's build
# would install it too. PW_TRACE=true records a trace of every test in tmp/traces
# (open one with `test/browser/node_modules/.bin/playwright show-trace <zip>`)
config :phoenix_test,
  otp_app: :fuel_calculator,
  playwright: [
    assets_dir: "test/browser",
    # Without the fade-ins, nothing is mid-animation when a test acts or asserts:
    # Playwright waits for a click target to stop moving, but not for the rest. A
    # test that sets browser_context_opts replaces this
    browser_context_opts: [reduced_motion: "reduce"],
    trace: System.get_env("PW_TRACE") == "true",
    trace_dir: "tmp/traces"
  ]

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Sort query params output of verified routes for robust url comparisons
config :phoenix,
  sort_verified_routes_query_params: true
