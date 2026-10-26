defmodule FuelCalculatorWeb.BrowserCase do
  @moduledoc """
  Runs a module's tests in Chromium through PhoenixTest.Playwright, with
  `mix test.browser`.

  Each test starts on `/` with the LiveView connected, and fails if the page
  logs an error: an uncaught exception, a `console.error` call, or a resource
  the Content Security Policy blocked.
  """

  use ExUnit.CaseTemplate

  import PhoenixTest

  using opts do
    quote do
      use PhoenixTest.Playwright.Case, unquote(opts)
      use FuelCalculatorWeb, :verified_routes

      # Not `:browser`: the Case reads module tags as its options, and that is one
      @moduletag :e2e

      setup {FuelCalculatorWeb.BrowserCase, :fail_on_page_errors}
      setup {FuelCalculatorWeb.BrowserCase, :visit_connected}
    end
  end

  @doc false
  def visit_connected(%{conn: conn}) do
    conn =
      conn
      |> visit("/")
      # visit/2 returns on the load event, before the LiveView joins
      |> assert_has("[data-phx-main].phx-connected")
      |> refute_has("#client-error")
      |> refute_has("#server-error")

    %{conn: conn}
  end

  @doc false
  # The browser reports errors as events while the test runs, so a process collects
  # them and the check runs once the test is over, before the Case closes the page
  # (on_exit callbacks run in reverse order)
  def fail_on_page_errors(%{conn: conn}) do
    # Not linked: the test process exits before on_exit runs, and would take it along
    collector = spawn(fn -> collect_page_errors([]) end)

    unwrap(conn, fn %{context_id: context_id, page_id: page_id} ->
      :ok = PlaywrightEx.subscribe(context_id, pid: collector)
      :ok = PlaywrightEx.subscribe(page_id, pid: collector)
    end)

    ExUnit.Callbacks.on_exit(fn ->
      send(collector, {:page_errors, self()})

      receive do
        {:page_errors, []} ->
          :ok

        {:page_errors, errors} ->
          raise ExUnit.AssertionError,
                "the page logged errors:\n" <> Enum.join(errors, "\n")
      after
        5_000 -> raise ExUnit.AssertionError, "the page errors collector didn't answer"
      end
    end)

    :ok
  end

  defp collect_page_errors(errors) do
    receive do
      {:playwright_msg, %{method: :page_error, params: %{error: error}}} ->
        collect_page_errors([page_error_message(error) | errors])

      {:playwright_msg, %{method: :console, params: %{type: "error", text: text}}} ->
        collect_page_errors([text | errors])

      {:playwright_msg, _msg} ->
        collect_page_errors(errors)

      {:page_errors, pid} ->
        send(pid, {:page_errors, errors |> Enum.reverse() |> Enum.uniq()})
    end
  end

  # A thrown value that isn't an Error has no name
  defp page_error_message(%{error: %{name: "", message: message}}), do: message
  defp page_error_message(%{error: %{name: name, message: message}}), do: "#{name}: #{message}"
  defp page_error_message(error), do: inspect(error)
end
