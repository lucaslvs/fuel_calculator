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
    {:noreply, assign_mission(socket, swap_steps(params))}
  end

  # The move buttons send steps_swap with the position of the step to swap with
  # the next one, in the same change event as the steps_sort they reorder.
  defp swap_steps(%{"steps_swap" => swap, "steps_sort" => sort} = params)
       when is_binary(swap) and is_list(sort) do
    case Integer.parse(swap) do
      {position, ""} when position >= 0 and position < length(sort) - 1 ->
        {before, [step, next | rest]} = Enum.split(sort, position)
        %{params | "steps_sort" => before ++ [next, step | rest]}

      _ ->
        params
    end
  end

  defp swap_steps(params), do: params

  defp assign_mission(socket, params) do
    changeset = Mission.changeset(%Mission{}, params)

    fuel =
      case Mission.calculate(changeset) do
        {:ok, fuel} -> fuel
        {:error, _changeset} -> nil
      end

    assign(socket,
      form: to_form(changeset, action: :validate),
      fuel: fuel,
      step_count: length(Ecto.Changeset.get_field(changeset, :steps))
    )
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header>
        Fuel calculator
        <:subtitle>Fuel required to fly a spacecraft along its flight path.</:subtitle>
      </.header>

      <div class="card card-border bg-base-100 shadow-sm">
        <.form
          for={@form}
          id="mission-form"
          class="card-body gap-4 p-4 sm:p-6"
          phx-change="validate"
          phx-submit="validate"
        >
          <.input
            field={@form[:mass]}
            type="number"
            label="Spacecraft mass (kg)"
            min="1"
            step="1"
          />

          <fieldset class="fieldset">
            <legend class="fieldset-legend">Flight path</legend>

            <div
              :if={@step_count == 0}
              id="empty-path"
              class="rounded-box border border-dashed border-base-300 p-6 text-center text-sm text-base-content/60"
            >
              <.icon name="hero-map" class="mb-1 size-6" />
              <p>No steps yet. Add a launch or a landing to plan the flight.</p>
            </div>

            <div id="steps" class="list">
              <.inputs_for :let={step} field={@form[:steps]}>
                <div
                  id={"step-#{step.index}"}
                  class="list-row items-start gap-2 px-0 py-2 motion-safe:animate-fade-in sm:gap-3"
                >
                  <span
                    data-role="step-number"
                    class="w-6 pt-1 text-center text-2xl font-thin tabular-nums opacity-40"
                  >
                    {step.index + 1}
                  </span>
                  <div class="list-col-grow flex flex-wrap gap-x-2">
                    <div class="min-w-28 flex-1">
                      <.input
                        field={step[:action]}
                        type="select"
                        prompt="Action"
                        options={@action_options}
                        aria-label={"Step #{step.index + 1} action"}
                      />
                    </div>
                    <div class="min-w-28 flex-1">
                      <.input
                        field={step[:planet]}
                        type="select"
                        prompt="Planet"
                        options={@planet_options}
                        aria-label={"Step #{step.index + 1} planet"}
                      />
                    </div>
                    <%!-- Keeps its width while the mission is invalid, so the selects don't jump --%>
                    <div class="flex w-full items-center sm:mb-2 sm:w-auto sm:min-w-28 sm:justify-end sm:py-1">
                      <span
                        :if={@fuel}
                        id={"step-fuel-#{step.index}"}
                        class="badge badge-soft badge-primary mb-2 tabular-nums sm:mb-0"
                      >
                        {format_kg(Enum.at(@fuel.steps, step.index))}
                      </span>
                    </div>
                  </div>
                  <div class="join join-vertical mt-1 sm:join-horizontal">
                    <.button
                      id={"move-step-up-#{step.index}"}
                      type="button"
                      name="mission[steps_swap]"
                      value={step.index - 1}
                      phx-click={JS.dispatch("change")}
                      disabled={step.index == 0}
                      class="btn btn-ghost btn-sm btn-square join-item sm:btn-md"
                      aria-label={"Move step #{step.index + 1} up"}
                    >
                      <.icon name="hero-chevron-up" class="size-5" />
                    </.button>
                    <.button
                      id={"move-step-down-#{step.index}"}
                      type="button"
                      name="mission[steps_swap]"
                      value={step.index}
                      phx-click={JS.dispatch("change")}
                      disabled={step.index == @step_count - 1}
                      class="btn btn-ghost btn-sm btn-square join-item sm:btn-md"
                      aria-label={"Move step #{step.index + 1} down"}
                    >
                      <.icon name="hero-chevron-down" class="size-5" />
                    </.button>
                    <.button
                      id={"remove-step-#{step.index}"}
                      type="button"
                      name="mission[steps_drop][]"
                      value={step.index}
                      phx-click={JS.dispatch("change")}
                      class="btn btn-ghost btn-sm btn-square join-item hover:text-error sm:btn-md"
                      aria-label={"Remove step #{step.index + 1}"}
                    >
                      <.icon name="hero-x-mark" class="size-5" />
                    </.button>
                  </div>
                  <input type="hidden" name="mission[steps_sort][]" value={step.index} />
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
              class="btn btn-soft btn-primary mt-2"
            >
              <.icon name="hero-plus" class="size-5" /> Add step
            </.button>
          </fieldset>
        </.form>
      </div>

      <div class="stats w-full border border-base-300 bg-base-200">
        <div class="stat">
          <div class="stat-figure text-primary">
            <.icon name="hero-fire" class="size-8" />
          </div>
          <div class="stat-title">Total fuel required</div>
          <div id="total-fuel" class="stat-value tabular-nums">
            {if @fuel, do: format_kg(@fuel.total), else: "—"}
          </div>
          <div class="stat-desc">
            {if @fuel,
              do: "Includes the fuel to carry the fuel",
              else: "Enter a mass and complete every step"}
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp format_kg(kg) do
    Regex.replace(~r/\B(?=(\d{3})+(?!\d))/, Integer.to_string(kg), ",") <> " kg"
  end
end
