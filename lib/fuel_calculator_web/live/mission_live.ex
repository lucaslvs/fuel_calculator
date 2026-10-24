defmodule FuelCalculatorWeb.MissionLive do
  @moduledoc """
  Builds a mission (spacecraft mass and flight path) and shows the fuel it requires,
  recalculated on every change.
  """

  use FuelCalculatorWeb, :live_view

  import FuelCalculatorWeb.MissionComponents

  alias FuelCalculator.FlightPath
  alias FuelCalculator.Mission

  # The missions of the challenge, as {id, label, mass, flight path}
  @examples [
    {"apollo-11", "Apollo 11", 28_801,
     [launch: :earth, land: :moon, launch: :moon, land: :earth]},
    {"mars", "Mars mission", 14_606, [launch: :earth, land: :mars, launch: :mars, land: :earth]},
    {"passenger-ship", "Passenger ship", 75_432,
     [launch: :earth, land: :moon, launch: :moon, land: :mars, launch: :mars, land: :earth]}
  ]

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(
       examples: @examples,
       max_mass: Mission.max_mass(),
       max_steps: Mission.max_steps()
     )
     # The form starts with one blank step, as if "Add step" had been clicked
     |> assign_mission(%{"steps_sort" => ["new"]})}
  end

  @impl true
  def handle_event("validate", %{"mission" => %{} = params}, socket) do
    params = params |> form_params() |> swap_steps()

    {:noreply, socket |> assign_mission(params) |> assign(focus_step: added_step(params))}
  end

  def handle_event("load_example", %{"id" => id}, socket) do
    case List.keyfind(@examples, id, 0) do
      {^id, _label, mass, path} -> {:noreply, assign_mission(socket, mission_params(mass, path))}
      nil -> {:noreply, socket}
    end
  end

  # Events come from the client and may have been crafted
  def handle_event(_event, _params, socket), do: {:noreply, socket}

  defp mission_params(mass, path) do
    steps =
      for {{action, planet}, index} <- Enum.with_index(path), into: %{} do
        {"#{index}", %{"action" => "#{action}", "planet" => "#{planet}"}}
      end

    %{"mass" => "#{mass}", "steps" => steps}
  end

  # Form inputs render their params back, which only works for the strings the form
  # sends, so a crafted event's other values are dropped.
  defp form_params(params) do
    params
    |> strings_only(~w(steps steps_sort steps_drop))
    |> Map.replace_lazy("steps", &form_steps/1)
  end

  defp form_steps(steps) when is_map(steps),
    do: Map.new(steps, fn {k, v} -> {k, form_step(v)} end)

  defp form_steps(steps) when is_list(steps), do: Enum.map(steps, &form_step/1)
  defp form_steps(steps), do: steps

  defp form_step(step) when is_map(step), do: strings_only(step, [])
  defp form_step(step), do: step

  defp strings_only(params, except) do
    Map.filter(params, fn {key, value} -> is_binary(value) or key in except end)
  end

  # The move buttons send steps_swap with the position of the step to swap with
  # the next one, in the same change event as the steps_sort they reorder. Longpoll
  # accepts much larger events than the websocket, and parsing a long enough
  # number raises, so the position is checked to have at most two digits first.
  defp swap_steps(%{"steps_swap" => swap, "steps_sort" => sort} = params)
       when is_binary(swap) and byte_size(swap) <= 2 and is_list(sort) do
    case Integer.parse(swap) do
      {position, ""} when position >= 0 and position < length(sort) - 1 ->
        {before, [step, next | rest]} = Enum.split(sort, position)
        %{params | "steps_sort" => before ++ [next, step | rest]}

      _ ->
        params
    end
  end

  defp swap_steps(params), do: params

  # "Add step" sends "new" in steps_sort, at the position the new step takes
  defp added_step(%{"steps_sort" => sort}) when is_list(sort),
    do: Enum.find_index(sort, &(&1 == "new"))

  defp added_step(_params), do: nil

  # Only the change that adds a step sets focus_step, so loading the page or an example
  # never takes the focus
  defp assign_mission(socket, params) do
    changeset = Mission.changeset(%Mission{}, params)
    steps = Ecto.Changeset.get_field(changeset, :steps)

    fuel =
      case Mission.calculate(changeset) do
        {:ok, fuel} -> fuel
        {:error, _changeset} -> nil
      end

    assign(socket,
      form: to_form(changeset, action: :validate),
      mass: valid_mass(changeset),
      focus_step: nil,
      fuel: fuel,
      step_count: length(steps),
      warnings: FlightPath.warnings(Enum.map(steps, &{&1.action, &1.planet}))
    )
  end

  defp valid_mass(changeset) do
    if Keyword.has_key?(changeset.errors, :mass),
      do: nil,
      else: Ecto.Changeset.get_field(changeset, :mass)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} class="max-w-5xl">
      <%!-- Below lg the fuel summary is a bar fixed to the bottom, hence the padding --%>
      <div class="max-lg:pb-8 lg:grid lg:grid-cols-[minmax(0,1fr)_20rem] lg:items-start lg:gap-6">
        <div class="space-y-4">
          <.header>
            Fuel calculator
            <:subtitle>Fuel required to fly a spacecraft along its flight path.</:subtitle>
          </.header>

          <.example_buttons examples={@examples} />

          <div class="card card-border bg-base-100 shadow-sm">
            <.form
              for={@form}
              id="mission-form"
              class="card-body gap-4 p-4 sm:p-6"
              phx-change="validate"
              phx-submit="validate"
            >
              <div>
                <.input
                  field={@form[:mass]}
                  type="number"
                  label="Spacecraft mass"
                  min="1"
                  max={@max_mass}
                  step="1"
                  inputmode="numeric"
                  placeholder="e.g. 28801"
                  phx-debounce="300"
                  aria-describedby={@mass && "mass-hint"}
                >
                  <:suffix>kg</:suffix>
                </.input>
                <p :if={@mass} id="mass-hint" class="label tabular-nums">{format_kg(@mass)}</p>
              </div>

              <.flight_path
                field={@form[:steps]}
                step_count={@step_count}
                max_steps={@max_steps}
                fuel={@fuel}
                mass={@mass}
                warnings={@warnings}
                focus_step={@focus_step}
              />
            </.form>
          </div>
        </div>

        <.fuel_summary fuel={@fuel} step_count={@step_count} />
      </div>
    </Layouts.app>
    """
  end
end
