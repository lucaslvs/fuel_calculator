defmodule FuelCalculatorWeb.ErrorHTML do
  @moduledoc """
  This module is invoked by your endpoint in case of errors on HTML requests.

  See config/config.exs.
  """
  use FuelCalculatorWeb, :html

  def render("404.html", _assigns) do
    error_page(%{
      status: 404,
      title: "Page not found",
      message: "There's nothing at this address."
    })
  end

  def render("500.html", _assigns) do
    error_page(%{
      status: 500,
      title: "Something went wrong",
      message: "The server couldn't handle this request. Try again in a moment."
    })
  end

  # Other errors only come from crafted requests, so they keep the plain status message
  def render(template, _assigns) do
    Phoenix.Controller.status_message_from_template(template)
  end

  # A page of its own rather than the app's layouts, so that a broken layout can't break
  # the error page too, and without the app's script, since there is no LiveView to join
  defp error_page(assigns) do
    ~H"""
    <!DOCTYPE html>
    <html lang="en">
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <title>{@title} · FuelCalculator</title>
        <link rel="icon" type="image/svg+xml" href={~p"/favicon.svg"} />
        <link rel="stylesheet" href={~p"/assets/css/app.css"} />
      </head>
      <body>
        <header class="px-4 sm:px-6 lg:px-8">
          <div class="navbar mx-auto min-h-16 max-w-2xl px-0">
            <.link href={~p"/"} class="btn btn-ghost -ms-3 px-3 text-lg">
              <.icon name="hero-rocket-launch" class="size-6" /> FuelCalculator
            </.link>
          </div>
        </header>

        <main class="px-4 pt-4 pb-20 sm:px-6 sm:pt-12 lg:px-8">
          <div id="error" class="card card-border bg-base-100 mx-auto max-w-2xl shadow-sm">
            <div class="card-body gap-3 p-6">
              <p class="text-sm text-base-content/70 tabular-nums">{@status}</p>
              <h1 class="text-2xl tracking-tight sm:text-4xl">{@title}</h1>
              <p class="text-base text-base-content/80">{@message}</p>
              <div class="card-actions mt-2">
                <.link id="go-home" href={~p"/"} class="btn btn-primary">Go to the calculator</.link>
              </div>
            </div>
          </div>
        </main>
      </body>
    </html>
    """
  end
end
