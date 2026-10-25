defmodule FuelCalculatorWeb.MissionLive do
  @moduledoc """
  Builds a mission (spacecraft mass and flight path) and shows the fuel it requires,
  recalculated on every change.
  """

  use FuelCalculatorWeb, :live_view

  import FuelCalculatorWeb.MissionComponents

  alias FuelCalculator.FlightPath
  alias FuelCalculator.Mission

  # The missions of the challenge
  @examples [
    %{
      id: "apollo-11",
      label: "Apollo 11",
      mass: 28_801,
      path: [launch: :earth, land: :moon, launch: :moon, land: :earth]
    },
    %{
      id: "mars",
      label: "Mars mission",
      mass: 14_606,
      path: [launch: :earth, land: :mars, launch: :mars, land: :earth]
    },
    %{
      id: "passenger-ship",
      label: "Passenger ship",
      mass: 75_432,
      path: [launch: :earth, land: :moon, launch: :moon, land: :mars, launch: :mars, land: :earth]
    }
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
    case Enum.find(@examples, &(&1.id == id)) do
      %{mass: mass, path: path} -> {:noreply, assign_mission(socket, mission_params(mass, path))}
      nil -> {:noreply, socket}
    end
  end

  # The fix is worked out from the mission on the server; the client only says which
  # step, by a position of at most two digits (see swap_steps/1)
  def handle_event("fix_step", %{"index" => index}, socket)
      when is_binary(index) and byte_size(index) <= 2 do
    changeset = socket.assigns.form.source

    with {index, ""} when index >= 0 <- Integer.parse(index),
         {action, planet} <- changeset |> path() |> FlightPath.fixes() |> Enum.at(index) do
      {:noreply, assign_mission(socket, fixed_params(changeset, index, action, planet))}
    else
      _ -> {:noreply, socket}
    end
  end

  # Events come from the client and may have been crafted
  def handle_event(_event, _params, socket), do: {:noreply, socket}

  # The params of the mission as it is, with the step replaced. Each step keeps the
  # params it was cast from, so a field the user hasn't touched still shows no error.
  defp fixed_params(changeset, index, action, planet) do
    steps =
      changeset
      |> Ecto.Changeset.get_embed(:steps, :changeset)
      |> Enum.map(& &1.params)
      |> List.update_at(
        index,
        &Map.merge(&1, %{"action" => "#{action}", "planet" => "#{planet}"})
      )

    %{"mass" => changeset.params["mass"], "steps" => steps}
  end

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
    mass = valid_mass(changeset)
    path = path(changeset)

    fuel =
      case Mission.calculate(changeset) do
        {:ok, fuel} -> fuel
        {:error, _changeset} -> nil
      end

    assign(socket,
      form: to_form(changeset, action: :validate),
      mass: mass,
      focus_step: nil,
      fuel: fuel,
      missing: Mission.missing(changeset),
      current_example_id: current_example_id(mass, path),
      step_count: length(path),
      warnings: FlightPath.warnings(path),
      fixes: FlightPath.fixes(path)
    )
  end

  defp path(changeset) do
    changeset |> Ecto.Changeset.get_field(:steps) |> Enum.map(&{&1.action, &1.planet})
  end

  # The example the mission matches, whether it was loaded or typed in, so editing
  # any of its values unmarks it
  defp current_example_id(mass, path) do
    Enum.find_value(@examples, fn
      %{id: id, mass: ^mass, path: ^path} -> id
      _example -> nil
    end)
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
          <header class="pb-4">
            <h1 class="text-2xl font-bold tracking-tight sm:text-4xl">
              Interplanetary <span class="text-primary">fuel</span> calculator
            </h1>
            <p class="mt-2 max-w-prose text-base text-base-content/80">
              Build a flight path of launches and landings and get the fuel it needs, step by step.
            </p>
          </header>

          <.example_cards examples={@examples} current_id={@current_example_id} />

          <div class="card card-border bg-base-100 shadow-sm">
            <.form
              for={@form}
              id="mission-form"
              class="card-body gap-4 p-4 sm:p-6"
              phx-change="validate"
              phx-submit="validate"
            >
              <.flight_path
                field={@form[:steps]}
                step_count={@step_count}
                max_steps={@max_steps}
                fuel={@fuel}
                mass={@mass}
                warnings={@warnings}
                fixes={@fixes}
                focus_step={@focus_step}
              >
                <:spacecraft>
                  <.input
                    field={@form[:mass]}
                    type="number"
                    label="Spacecraft mass"
                    label_class="mb-1 block text-sm font-semibold"
                    class="input w-full tabular-nums"
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
                  <p
                    :if={@mass}
                    id="mass-hint"
                    class="mt-1 text-sm text-base-content/80 tabular-nums"
                  >
                    {format_kg(@mass)}
                  </p>
                </:spacecraft>
              </.flight_path>
            </.form>
          </div>
        </div>

        <.fuel_summary
          fuel={@fuel}
          missing={@missing}
          warnings={@warnings}
          step_count={@step_count}
        />
      </div>
    </Layouts.app>
    """
  end
end
