defmodule FuelCalculatorWeb.MissionLive do
  @moduledoc """
  Builds a mission (spacecraft mass and flight path) and shows the fuel it requires,
  recalculated on every change.
  """

  use FuelCalculatorWeb, :live_view

  alias FuelCalculator.Mission
  alias FuelCalculator.Mission.Step
  alias FuelCalculator.Planet

  @action_options Enum.map(Ecto.Enum.values(Step, :action), &{String.capitalize("#{&1}"), &1})
  @planet_options Enum.map(Planet.all(), &{String.capitalize("#{&1}"), &1})

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(action_options: @action_options, planet_options: @planet_options)
     # The form starts with one blank step, as if "Add step" had been clicked
     |> assign_mission(%{"steps_sort" => ["new"]})}
  end

  @impl true
  def handle_event("validate", %{"mission" => params}, socket) do
    {:noreply, assign_mission(socket, params)}
  end

  defp assign_mission(socket, params) do
    changeset = Mission.changeset(%Mission{}, params)

    fuel =
      case Mission.calculate(changeset) do
        {:ok, fuel} -> fuel
        {:error, _changeset} -> nil
      end

    assign(socket, form: to_form(changeset, action: :validate), fuel: fuel)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header>
        Fuel calculator
        <:subtitle>Fuel required to fly a spacecraft along its flight path.</:subtitle>
      </.header>

      <.form for={@form} id="mission-form" phx-change="validate" phx-submit="validate">
        <.input
          field={@form[:mass]}
          type="number"
          label="Spacecraft mass (kg)"
          min="1"
          step="1"
        />

        <div id="steps">
          <.inputs_for :let={step} field={@form[:steps]}>
            <div id={"step-#{step.index}"} class="flex items-start gap-2">
              <input type="hidden" name="mission[steps_sort][]" value={step.index} />
              <div class="flex-1">
                <.input
                  field={step[:action]}
                  type="select"
                  prompt="Action"
                  options={@action_options}
                />
              </div>
              <div class="flex-1">
                <.input
                  field={step[:planet]}
                  type="select"
                  prompt="Planet"
                  options={@planet_options}
                />
              </div>
              <.button
                id={"remove-step-#{step.index}"}
                type="button"
                name="mission[steps_drop][]"
                value={step.index}
                phx-click={JS.dispatch("change")}
                class="btn btn-ghost btn-square"
                aria-label="Remove step"
              >
                <.icon name="hero-x-mark" class="size-5" />
              </.button>
            </div>
          </.inputs_for>
        </div>

        <input type="hidden" name="mission[steps_drop][]" />

        <.button
          id="add-step"
          type="button"
          name="mission[steps_sort][]"
          value="new"
          phx-click={JS.dispatch("change")}
        >
          <.icon name="hero-plus" class="size-5" /> Add step
        </.button>
      </.form>

      <div class="stats shadow">
        <div class="stat">
          <div class="stat-title">Total fuel required</div>
          <div id="total-fuel" class="stat-value">
            {if @fuel, do: "#{@fuel.total} kg", else: "—"}
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
