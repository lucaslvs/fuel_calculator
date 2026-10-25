defmodule FuelCalculatorWeb.MissionComponents do
  @moduledoc """
  Components of the mission page: the example missions, the flight path and the fuel
  summary.

  The flight path components render inside `FuelCalculatorWeb.MissionLive`'s form and
  send its `steps_sort` and `steps_drop` params.
  """

  use FuelCalculatorWeb, :html

  alias FuelCalculator.Fuel
  alias FuelCalculator.Planet

  @doc """
  Renders a card per example mission, which sends `load_example` with its id, and marks
  the one the mission matches.

  Below `sm` the cards only show the name and the number of steps, so the loaded one's
  route and mass are shown below them. The check is hidden there too: next to the name
  it wraps the longer names to a second line.
  """
  attr :examples, :list,
    required: true,
    doc: "the example missions, as maps with their `:id`, `:label`, `:mass` and `:path`"

  attr :current_id, :string, default: nil, doc: "the id of the example the mission matches"

  def example_cards(assigns) do
    assigns =
      assign(assigns, :current, Enum.find(assigns.examples, &(&1.id == assigns.current_id)))

    ~H"""
    <div class="space-y-2">
      <div>
        <h2 class="text-sm font-semibold">Example missions</h2>
        <p class="text-xs text-base-content/80">Each one replaces the mass and the flight path.</p>
      </div>
      <div class="grid grid-cols-3 gap-2">
        <button
          :for={example <- @examples}
          id={"example-#{example.id}"}
          type="button"
          phx-click="load_example"
          phx-value-id={example.id}
          aria-current={example.id == @current_id && "true"}
          class={[
            "card card-sm card-border bg-base-100 cursor-pointer text-start sm:transition-colors sm:hover:border-primary",
            "focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary",
            example.id == @current_id && "border-primary"
          ]}
        >
          <span class="card-body gap-1 p-2 sm:p-3">
            <span class="flex items-start justify-between gap-1">
              <span class="font-semibold leading-tight">{example.label}</span>
              <.icon
                :if={example.id == @current_id}
                name="hero-check-circle-mini"
                class="size-4 shrink-0 text-primary max-sm:hidden"
              />
            </span>
            <.example_route path={example.path} class="max-sm:hidden" />
            <span
              data-role="size"
              class="text-xs tabular-nums text-base-content/80 max-sm:hidden"
            >
              {example_size(example)}
            </span>
            <span class="text-xs tabular-nums text-base-content/80 sm:hidden">
              {length(example.path)} steps
            </span>
          </span>
        </button>
      </div>
      <p
        :if={@current}
        id="loaded-example"
        class="flex flex-wrap items-center gap-x-2 text-xs text-base-content/80 sm:hidden"
      >
        <.example_route path={@current.path} />
        <span class="tabular-nums">· {example_size(@current)}</span>
      </p>
    </div>
    """
  end

  # The planets the flight path visits, without repeating the one a step lands on
  # when the next step launches from it
  attr :path, :list, required: true
  attr :class, :string, default: nil

  defp example_route(assigns) do
    assigns = assign(assigns, :planets, assigns.path |> Enum.map(&elem(&1, 1)) |> Enum.dedup())

    ~H"""
    <span class={["flex flex-wrap items-center gap-x-1 text-xs text-base-content/80", @class]}>
      <%= for {planet, index} <- Enum.with_index(@planets) do %>
        <.icon
          :if={index > 0}
          name="hero-arrow-long-right-micro"
          class="size-3.5 opacity-70"
        />
        <span data-role="planet">{capitalize(planet)}</span>
      <% end %>
    </span>
    """
  end

  defp example_size(example), do: "#{format_kg(example.mass)} · #{length(example.path)} steps"

  @doc """
  Renders the flight path as a timeline: the spacecraft first, then a node per step, and
  last the card that adds a step, with the steps' errors. The card only shows once a
  step can follow, so the timeline is filled in order and ends at the node to fill in.

  The steps are a fieldset of their own, so screen readers don't announce the
  spacecraft's fields as part of their group.
  """
  attr :field, Phoenix.HTML.FormField, required: true, doc: "the mission's steps field"
  attr :step_count, :integer, required: true
  attr :max_steps, :integer, required: true
  attr :fuel, :map, default: nil, doc: "the mission's fuel, or nil while it is invalid"
  attr :mass, :integer, default: nil, doc: "the spacecraft mass, or nil while it is invalid"

  attr :warnings, :list,
    default: [],
    doc: "a warning or nil for each step (see `FuelCalculator.FlightPath.warnings/1`)"

  attr :fixes, :list,
    default: [],
    doc:
      "the step that would replace each step with a warning (see `FuelCalculator.FlightPath.fixes/1`)"

  attr :focus_step, :integer, default: nil, doc: "the index of the step that takes the focus"

  attr :next_step, :boolean,
    default: false,
    doc: "whether a step can follow: the mass is valid and the last step complete"

  slot :spacecraft, required: true, doc: "the spacecraft's fields, in the first node"

  def flight_path(assigns) do
    assigns = assign(assigns, :steps_left, assigns.max_steps - assigns.step_count)

    ~H"""
    <div>
      <div class="flex items-baseline justify-between gap-2">
        <h2 class="text-sm font-semibold">Flight path</h2>
        <%!-- Only close to the limit; at the limit, the note next to "Add step" says it --%>
        <span
          :if={@steps_left in 1..3}
          id="steps-left"
          class="text-xs text-base-content/80 tabular-nums"
        >
          {@steps_left} more {if(@steps_left == 1, do: "step", else: "steps")} allowed
        </span>
      </div>

      <%!-- Only the steps are a list for screen readers: the spacecraft and the "Add step"
      node are timelines of their own, joined to the steps', with list markup for the
      timeline's layout only --%>
      <ul class="timeline timeline-vertical timeline-compact mt-3 w-full" role="none">
        <li data-role="spacecraft" class="w-full [--timeline-row-start:0]" role="none">
          <div class="timeline-middle">
            <%!-- Dashed like the "Add step" node until the mass is valid, then in the
                 primary color, as a step is once its action and planet are chosen --%>
            <span
              data-role="spacecraft-icon"
              class={[
                "grid size-8 place-items-center rounded-full transition-colors",
                if(@mass,
                  do: "bg-primary text-primary-content",
                  else: "border border-dashed border-base-content/40 text-base-content/80"
                )
              ]}
            >
              <.icon name="hero-rocket-launch" class="size-4" />
            </span>
          </div>
          <div class="timeline-end ms-3 mb-5 w-[calc(100%-0.75rem)] min-w-0 pt-1">
            {render_slot(@spacecraft)}
          </div>
          <hr :if={@step_count > 0 or @next_step} class="bg-base-300" aria-hidden="true" />
        </li>
      </ul>

      <fieldset id="flight-path-steps" class="fieldset p-0">
        <legend class="sr-only">Steps</legend>
        <%!-- One child of the fieldset, so its gap doesn't split the two timelines --%>
        <div>
          <ul id="steps" class="timeline timeline-vertical timeline-compact w-full">
            <%!-- A ul only holds li, so each step renders its own hidden fields --%>
            <.inputs_for :let={step} field={@field} skip_hidden>
              <.step_row
                step={step}
                step_count={@step_count}
                detail={@fuel && Enum.at(@fuel.details, step.index)}
                mass={@mass}
                warning={Enum.at(@warnings, step.index)}
                fix={Enum.at(@fixes, step.index)}
                next_warning={!is_nil(Enum.at(@warnings, step.index + 1))}
                continues={step.index < @step_count - 1 or @next_step}
                focus={step.index == @focus_step}
              />
            </.inputs_for>
          </ul>
          <ul :if={@next_step} class="timeline timeline-vertical timeline-compact w-full" role="none">
            <%!-- The card opens the actions in its place: data-open marks the item while
                 they are shown, and the node turns into a close mark --%>
            <li
              id="add-step-item"
              class="group/add w-full [--timeline-row-start:0] motion-safe:animate-fade-in"
              role="none"
            >
              <hr class="bg-base-300" aria-hidden="true" />
              <div class="timeline-middle">
                <%!-- A larger target for the pointer; the keyboard reaches the card --%>
                <span
                  aria-hidden="true"
                  phx-click={@step_count < @max_steps && open_add_step()}
                  class={[
                    "grid size-8 place-items-center rounded-full border border-dashed",
                    "border-base-content/40 text-base-content/80 transition-colors",
                    if(@step_count < @max_steps,
                      do: [
                        "cursor-pointer group-hover/add:border-solid group-hover/add:border-primary",
                        "group-hover/add:bg-primary/15 group-hover/add:text-primary",
                        "group-has-[#add-step:focus-visible]/add:border-solid",
                        "group-has-[#add-step:focus-visible]/add:border-primary",
                        "group-has-[#add-step:focus-visible]/add:text-primary"
                      ],
                      else: "opacity-50"
                    ),
                    "group-data-open/add:pointer-events-none group-data-open/add:border-solid",
                    "group-data-open/add:border-primary group-data-open/add:bg-primary/15",
                    "group-data-open/add:text-primary"
                  ]}
                >
                  <.icon
                    name="hero-plus"
                    class={[
                      "size-4 transition-transform duration-200 motion-reduce:transition-none",
                      @step_count < @max_steps && "group-hover/add:rotate-90",
                      "group-data-open/add:rotate-135"
                    ]}
                  />
                </span>
              </div>
              <div class="timeline-end ms-3 w-[calc(100%-0.75rem)] min-w-0">
                <.button
                  id="add-step"
                  type="button"
                  phx-click={open_add_step()}
                  disabled={@step_count >= @max_steps}
                  class={[
                    "btn btn-dash h-13 w-full justify-start border-base-content/35 px-3.5 font-semibold",
                    "disabled:border-base-content/20 disabled:bg-transparent group-data-open/add:hidden",
                    "enabled:group-hover/add:border-solid enabled:group-hover/add:border-primary",
                    "enabled:group-hover/add:bg-primary/8"
                  ]}
                >
                  Add step
                </.button>
                <%!-- Each action adds a step that starts with it --%>
                <div
                  id="add-step-actions"
                  role="group"
                  aria-label="Add step"
                  phx-click-away={close_add_step()}
                  class={[
                    "hidden h-13 items-center gap-2 rounded-field border border-primary bg-primary/6 px-2.5",
                    "group-data-open/add:flex motion-safe:animate-fade-in"
                  ]}
                >
                  <.button
                    :for={action <- Fuel.actions()}
                    id={"add-step-#{action}"}
                    type="button"
                    name="mission[steps_sort][]"
                    value={"new_#{action}"}
                    phx-click={"change" |> JS.dispatch() |> close_add_step()}
                    phx-keydown={close_add_step() |> JS.focus(to: "#add-step")}
                    phx-key="Escape"
                    class="btn btn-sm rounded-full border-base-300 bg-base-200 hover:border-primary hover:text-primary"
                  >
                    <.icon name={step_icon({action, nil})} class="size-4" /> {capitalize(action)}
                  </.button>
                </div>
                <p
                  :if={@step_count >= @max_steps}
                  id="step-limit"
                  class="flex items-center gap-1 pt-1.5 text-xs text-base-content/80"
                >
                  <.icon name="hero-information-circle-micro" class="size-4" />
                  A flight path has at most {@max_steps} steps.
                </p>
                <div :if={@field.errors != []} id="steps-errors" class="pt-1.5">
                  <p
                    :for={msg <- Enum.map(@field.errors, &translate_error/1)}
                    class="flex items-center gap-2 text-sm text-error"
                  >
                    <.icon name="hero-exclamation-circle" class="size-5" />
                    {msg}
                  </p>
                </div>
              </div>
            </li>
          </ul>
        </div>
        <input type="hidden" name="mission[steps_drop][]" />
      </fieldset>
    </div>
    """
  end

  @doc """
  Renders a step of the flight path as a timeline item: an icon of its action, a title
  with its number, action and planet, its fuel, its action and planet, the button that
  removes it, a warning when it can't follow the previous step, and how its fuel is
  calculated.

  Removing a step re-renders the rows by position, so the button also moves the focus
  to the one that keeps the user's place, which exists before and after the change:
  the previous step's remove button.
  """
  attr :step, Phoenix.HTML.Form, required: true, doc: "the step's form, from `inputs_for`"
  attr :step_count, :integer, required: true

  attr :detail, :map,
    default: nil,
    doc:
      "the step's fuel and how it is calculated (see `FuelCalculator.Fuel.explain/2`), " <>
        "or nil while the mission is invalid"

  attr :mass, :integer, default: nil, doc: "the spacecraft mass, or nil while it is invalid"
  attr :warning, :any, default: nil, doc: "why the step can't follow the previous one, or nil"
  attr :fix, :any, default: nil, doc: "the `{action, planet}` that would follow, or nil"

  attr :next_warning, :boolean,
    default: false,
    doc: "whether the next step can't follow this one"

  attr :continues, :boolean,
    default: true,
    doc: "whether the timeline goes on below the step, to another step or to Add step"

  attr :focus, :boolean, default: false, doc: "whether the step takes the focus when added"

  def step_row(assigns) do
    assigns = assign(assigns, :chosen, chosen(assigns.step.source))

    ~H"""
    <li
      id={"step-#{@step.index}"}
      class="w-full [--timeline-row-start:0] motion-safe:animate-fade-in"
      phx-mounted={@focus && JS.focus(to: "##{@step[:planet].id}")}
    >
      <%!-- The spacecraft comes before the steps and "Add step" after them. The line
           that leads to a step that can't follow the previous one is in the warning
           color: the previous step's half and this one's. --%>
      <hr class={if(@warning, do: "bg-warning", else: "bg-base-300")} aria-hidden="true" />
      <div class="timeline-middle">
        <span
          data-role="step-icon"
          class={[
            "grid size-8 place-items-center rounded-full",
            cond do
              @warning -> "bg-warning text-warning-content"
              @chosen -> "bg-primary text-primary-content"
              true -> "bg-base-200 text-base-content/70"
            end
          ]}
        >
          <.icon
            name={if(@warning, do: "hero-exclamation-triangle-mini", else: step_icon(@chosen))}
            class="size-4"
          />
        </span>
      </div>
      <div class="timeline-end ms-3 mb-5 w-[calc(100%-0.75rem)] min-w-0">
        <%!-- The step's fuel is in its details' summary and in "Fuel by step" --%>
        <p data-role="step-title" class="pt-1 text-sm font-semibold">
          {@step.index + 1} · {step_title(@chosen)}
        </p>
        <div class="mt-2 flex flex-wrap items-start gap-x-2 gap-y-2">
          <%!-- With the 4px the select's fieldset adds above it, the paddings center the
               36px action group, the select and the remove button on the same line. --%>
          <div class="flex-none pt-0.5">
            <.action_toggle
              field={@step[:action]}
              label={"Step #{@step.index + 1} action"}
              options={action_options()}
              warning={warning_field(@warning) == :action}
            />
          </div>
          <div class="min-w-28 flex-1">
            <%!-- An added step focuses its planet: below lg the margin keeps the rest of
                 the step out from under the fixed fuel bar --%>
            <.input
              field={@step[:planet]}
              type="select"
              prompt="Planet"
              options={planet_options()}
              class={[
                "select select-sm w-full max-lg:scroll-mb-24",
                warning_field(@warning) == :planet && "select-warning"
              ]}
              aria-label={"Step #{@step.index + 1} planet"}
              aria-describedby={@warning && "step-warning-#{@step.index}"}
            />
          </div>
          <div class="flex items-center pt-1">
            <.button
              id={"remove-step-#{@step.index}"}
              type="button"
              name="mission[steps_drop][]"
              value={@step.index}
              phx-click={change_and_focus(remove_focus(@step.index, @step_count))}
              class="btn btn-ghost btn-sm btn-square text-base-content/70 hover:text-error"
              aria-label={"Remove step #{@step.index + 1}"}
            >
              <.icon name="hero-x-mark" class="size-4" />
            </.button>
          </div>
        </div>
        <div>
          <.step_warning index={@step.index} warning={@warning} fix={@fix} />
          <.step_details
            index={@step.index}
            last={@step.index == @step_count - 1}
            detail={@detail}
            mass={@mass}
          />
        </div>
        <input type="hidden" name="mission[steps_sort][]" value={@step.index} />
        <input
          :for={{name, value} <- @step.hidden}
          type="hidden"
          name={Phoenix.HTML.Form.input_name(@step, name)}
          value={value}
        />
      </div>
      <hr
        :if={@continues}
        class={if(@next_warning, do: "bg-warning", else: "bg-base-300")}
        aria-hidden="true"
      />
    </li>
    """
  end

  # The step's action and planet, once both are chosen
  defp chosen(step) do
    case {Ecto.Changeset.get_field(step, :action), Ecto.Changeset.get_field(step, :planet)} do
      {nil, _planet} -> nil
      {_action, nil} -> nil
      chosen -> chosen
    end
  end

  defp step_title({action, planet}), do: action_on(action, planet)
  defp step_title(nil), do: "Choose an action and a planet"

  defp step_icon({:launch, _planet}), do: "hero-arrow-up-right"
  defp step_icon({:land, _planet}), do: "hero-arrow-down-right"
  defp step_icon(nil), do: "hero-ellipsis-horizontal"

  # data-open swaps the card for the actions in CSS: JS.show and JS.hide apply the
  # display on the next frame, too late for the focus to move to an action
  defp open_add_step do
    {"data-open", ""}
    |> JS.set_attribute(to: "#add-step-item")
    |> JS.focus_first(to: "#add-step-actions")
  end

  defp close_add_step(js \\ %JS{}), do: JS.remove_attribute(js, "data-open", to: "#add-step-item")

  defp change_and_focus(nil), do: JS.dispatch("change")
  defp change_and_focus(selector), do: "change" |> JS.dispatch() |> JS.focus(to: selector)

  defp remove_focus(0, 1), do: "#add-step"
  defp remove_focus(0, _count), do: nil
  defp remove_focus(index, _count), do: "#remove-step-#{index - 1}"

  attr :index, :integer, required: true
  attr :warning, :any, default: nil
  attr :fix, :any, default: nil

  # Hidden rather than removed: inserting it would move the details after it, and
  # moving the focused summary drops its focus. The live region around it is always
  # there, since screen readers only announce changes inside an existing region, and
  # the warning carries the margin so the empty region takes no space.
  defp step_warning(assigns) do
    ~H"""
    <div aria-live="polite">
      <div
        id={"step-warning-#{@index}"}
        hidden={is_nil(@warning)}
        class="mb-2 flex flex-wrap items-start gap-x-3 gap-y-1.5 text-sm"
      >
        <p class="flex items-start gap-2">
          <.icon name="hero-exclamation-triangle-mini" class="size-5 shrink-0 text-warning" />
          <span>{@warning && warning_message(@warning, @index)}</span>
        </p>
        <%!-- The button stays in place, so the focus moves to the field it changes --%>
        <.button
          :if={@fix}
          id={"fix-step-#{@index}"}
          type="button"
          phx-click={
            "fix_step"
            |> JS.push(value: %{index: "#{@index}"})
            |> JS.focus(to: fixed_field(@warning, @fix, @index))
          }
          class="btn btn-xs btn-warning"
        >
          <.icon name="hero-wrench-screwdriver-micro" class="size-3.5" />
          {fix_label(@fix)}
        </.button>
      </div>
    </div>
    """
  end

  # Steps are numbered from 1, so the previous step's number is this step's index
  defp warning_message({:launch_elsewhere, planet, landed_on}, index),
    do:
      "Launches from #{planet_name(planet)}, but step #{index} landed on #{planet_name(landed_on)}."

  defp warning_message(:land_twice, index),
    do: "Lands again without launching after step #{index}."

  defp warning_message(:launch_twice, index),
    do: "Launches again without landing after step #{index}."

  defp fix_label({action, planet}), do: "#{action_on(action, planet)} instead"

  defp fixed_field(warning, {action, _planet}, index) do
    case warning_field(warning) do
      :planet -> "#mission_steps_#{index}_planet"
      :action -> "#mission_steps_#{index}_action_#{action}"
    end
  end

  # The field to change so the step can follow the previous one
  defp warning_field({:launch_elsewhere, _planet, _landed_on}), do: :planet
  defp warning_field(:land_twice), do: :action
  defp warning_field(:launch_twice), do: :action
  defp warning_field(nil), do: nil

  attr :index, :integer, required: true
  attr :last, :boolean, default: false
  attr :detail, :map, default: nil
  attr :mass, :integer, default: nil

  # Kept while the mission is invalid, so the rows don't shrink and an open one stays
  # open. The browser sets "open", which every patch would remove.
  defp step_details(assigns) do
    ~H"""
    <details
      id={"step-details-#{@index}"}
      class="collapse collapse-arrow rounded-box bg-base-200 text-sm"
      phx-mounted={JS.ignore_attributes("open")}
    >
      <summary class="collapse-title min-h-0 py-2 ps-3 pe-10 text-sm text-base-content/80">
        {if @detail,
          do: "How #{format_kg(@detail.fuel)} is calculated",
          else: "How the fuel is calculated"}<span class="sr-only"> in step {@index + 1}</span>
      </summary>
      <div class="collapse-content space-y-1 px-3 tabular-nums wrap-anywhere">
        <%= if @detail do %>
          <p data-role="mass">{carried_mass(@detail.mass, @mass, @last)}</p>
          <p data-role="formula">{formula(@detail.action, @detail.planet)}</p>
          <p data-role="iterations">
            <%= case @detail.iterations do %>
              <% [] -> %>
                No fuel needed: the formula gives zero or less for this mass.
              <% [fuel] -> %>
                <strong class="font-semibold">{format_kg(fuel)}</strong>
              <% iterations -> %>
                {Enum.map_join(iterations, " + ", &format_number/1)} =
                <strong class="font-semibold">{format_kg(@detail.fuel)}</strong>
            <% end %>
          </p>
        <% else %>
          <p>Complete the mission to see the calculation.</p>
        <% end %>
      </div>
    </details>
    """
  end

  # Earlier steps can carry just the spacecraft too, when the later steps need no fuel
  defp carried_mass(mass, _spacecraft, true), do: "Mass: #{format_kg(mass)} (no later steps)"

  defp carried_mass(mass, spacecraft, false) do
    "Mass: #{format_kg(spacecraft)} spacecraft + #{format_kg(mass - spacecraft)} " <>
      "of fuel for the later steps = #{format_kg(mass)}"
  end

  defp formula(action, planet) do
    {factor, offset} = Fuel.formula(action)

    "#{action_on(action, planet)}: mass × #{Planet.gravity(planet)} × #{factor} − #{offset}, " <>
      "rounded down, then again on that fuel until it is zero or less"
  end

  defp action_on(:launch, planet), do: "Launch from #{planet_name(planet)}"
  defp action_on(:land, planet), do: "Land on #{planet_name(planet)}"

  defp planet_name(:moon), do: "the Moon"
  defp planet_name(planet), do: capitalize(planet)

  defp action_options, do: Enum.map(Fuel.actions(), &{capitalize(&1), &1})
  defp planet_options, do: Enum.map(Planet.all(), &{capitalize(&1), &1})

  defp capitalize(atom), do: atom |> Atom.to_string() |> String.capitalize()

  @doc """
  Renders a step's action as a group of radio buttons, one per action.

  While no action is checked the browser sends nothing for the radios, so a hidden
  empty input keeps the action in the params: without it the field never counts as
  used and its error stays hidden, even on submit.
  """
  attr :field, Phoenix.HTML.FormField, required: true, doc: "the step's action field"
  attr :label, :string, required: true, doc: "the accessible name of the group"
  attr :options, :list, required: true, doc: "the actions, as `{label, value}` tuples"

  attr :warning, :boolean,
    default: false,
    doc: "whether the action keeps the step from following the previous one"

  def action_toggle(%{field: field} = assigns) do
    errors = if used_input?(field), do: field.errors, else: []

    assigns =
      assign(assigns,
        errors: Enum.map(errors, &translate_error/1),
        checked: to_string(field.value)
      )

    ~H"""
    <fieldset
      id={@field.id}
      class="fieldset p-0"
      role="radiogroup"
      aria-invalid={@errors != [] && "true"}
      aria-describedby={@errors != [] && "#{@field.id}-error"}
    >
      <legend class="sr-only">{@label}</legend>
      <input type="hidden" name={@field.name} value="" />
      <%!-- The checked option follows the radio's :checked, so it changes on click --%>
      <div class={[
        "inline-flex gap-0.5 rounded-field bg-base-200 p-0.5",
        @errors != [] && "ring-1 ring-error",
        @warning && "ring-2 ring-warning"
      ]}>
        <label
          :for={{label, value} <- @options}
          for={Phoenix.HTML.Form.input_id(@field.form, @field.field, value)}
          class={[
            "btn btn-sm btn-ghost gap-1 border-0 text-base-content/80",
            "has-checked:bg-base-100 has-checked:text-primary has-checked:shadow-sm",
            "has-focus-visible:outline-2 has-focus-visible:outline-offset-2",
            "has-focus-visible:outline-primary"
          ]}
        >
          <input
            type="radio"
            id={Phoenix.HTML.Form.input_id(@field.form, @field.field, value)}
            name={@field.name}
            value={value}
            checked={to_string(value) == @checked}
            class="sr-only"
          />
          <.icon name={action_icon(value)} class="size-4" />
          {label}
        </label>
      </div>
      <div :if={@errors != []} id={"#{@field.id}-error"}>
        <p :for={msg <- @errors} class="mt-1.5 flex items-center gap-2 text-sm text-error">
          <.icon name="hero-exclamation-circle" class="size-5" />
          {msg}
        </p>
      </div>
    </fieldset>
    """
  end

  defp action_icon(:launch), do: "hero-arrow-up-circle"
  defp action_icon(:land), do: "hero-arrow-down-circle"

  @doc """
  Renders the mission's total fuel or, while the mission is invalid, what it still
  lacks. Screen readers announce
  the total whenever it changes. When steps can't follow the previous one, it says so,
  since the total covers the steps as entered.

  On large screens it is a card with an aura that sticks to the top of its column, and
  breaks the total down by step; below that, the same element is a compact bar fixed to
  the bottom of the screen, with the number of steps (or what is missing, or a warning)
  in place of the icon, the description and the breakdown.
  """
  attr :fuel, :map,
    default: nil,
    doc: "the mission's fuel, or nil while it is invalid or has no steps"

  attr :missing, :list,
    default: [],
    doc:
      "what the mission lacks (see `FuelCalculator.Mission.missing/1`), and " <>
        "`:first_step` while the flight path is empty"

  attr :warnings, :list,
    default: [],
    doc: "a warning or nil for each step (see `FuelCalculator.FlightPath.warnings/1`)"

  attr :step_count, :integer, required: true

  def fuel_summary(assigns) do
    assigns =
      assign(
        assigns,
        :warned,
        for({warning, index} <- Enum.with_index(assigns.warnings), warning, do: index)
      )

    ~H"""
    <%!-- The aura colors the text with its glow, so the card resets it --%>
    <div class="block w-full text-primary motion-reduce:animate-none lg:aura lg:aura-sm lg:sticky lg:top-6">
      <div
        id="fuel-summary"
        class={[
          "card card-border w-full bg-base-100 text-base-content shadow-sm",
          "max-lg:fixed max-lg:inset-x-0 max-lg:bottom-0 max-lg:z-40 max-lg:rounded-none",
          "max-lg:border-x-0 max-lg:border-b-0 max-lg:shadow-lg"
        ]}
      >
        <div class="stat max-lg:px-4 max-lg:py-3">
          <div class={[
            "stat-figure max-lg:hidden",
            if(@fuel, do: "text-primary", else: "text-base-content/30")
          ]}>
            <.icon name="hero-fire" class="size-8" />
          </div>
          <div
            id="fuel-summary-steps"
            class="stat-figure max-w-40 text-end text-sm text-base-content/70 lg:hidden"
          >
            <%!-- One button for both labels, so its expanded state survives a new warning.
                 JS commands keep their changes across patches. --%>
            <.button
              :if={@fuel}
              id="fuel-by-step-toggle"
              type="button"
              class="group btn btn-ghost btn-sm -me-2 gap-1 px-2 font-normal"
              aria-expanded="false"
              aria-controls="fuel-by-step-panel"
              phx-click={
                JS.toggle_class("max-lg:hidden", to: "#fuel-by-step-panel")
                |> JS.toggle_attribute({"aria-expanded", "true", "false"})
              }
            >
              <span data-role="status">
                <%= if @warned != [] do %>
                  <span class="badge badge-warning badge-sm gap-1">
                    <.icon name="hero-exclamation-triangle-micro" class="size-3.5" /><span class="sr-only">Warning: </span>{warned_label(
                      @warned
                    )}
                  </span>
                <% else %>
                  {steps_label(@step_count)}
                <% end %>
              </span>
              <span class="sr-only">, fuel by step</span>
              <.icon
                name="hero-chevron-up-mini"
                class="size-4 transition-transform group-aria-expanded:rotate-180 motion-reduce:transition-none"
              />
            </.button>
            <%= if is_nil(@fuel) do %>
              {missing_label(@missing)}
            <% end %>
          </div>
          <div class="stat-title text-base-content/70">Total fuel required</div>
          <div
            id="total-fuel"
            class={[
              "stat-value font-normal tabular-nums",
              if(@fuel,
                do: total_size(format_kg(@fuel.total)),
                else: "text-2xl text-base-content/70 max-lg:text-lg"
              )
            ]}
            aria-live="polite"
            aria-atomic="true"
          >
            {if @fuel, do: format_kg(@fuel.total), else: "Not calculated yet"}
          </div>
          <div :if={@fuel && @warned == []} class="stat-desc text-base-content/70 max-lg:hidden">
            Includes the fuel to carry the fuel
          </div>
          <p
            :if={@fuel && @warned != []}
            id="fuel-warnings"
            class="stat-desc mt-1 flex items-start gap-1.5 text-sm whitespace-normal text-base-content max-lg:hidden"
          >
            <.icon name="hero-exclamation-triangle-mini" class="size-5 shrink-0 text-warning" />
            <span>
              {warned_sentence(@warned)}
              <span class="text-base-content/70">The total covers the steps as entered.</span>
            </span>
          </p>
          <.fuel_pending :if={!@fuel} missing={@missing} />
        </div>
        <.fuel_by_step
          :if={@fuel}
          details={@fuel.details}
          warned={@warned}
        />
      </div>
    </div>
    """
  end

  # The total doesn't wrap and the summary card is narrow: a figure takes about half an em,
  # and the longest total (15 launches from Earth at the largest mass) has 24 characters
  defp total_size(total) do
    case String.length(total) do
      length when length <= 13 -> "max-lg:text-2xl"
      length when length <= 17 -> "text-2xl max-lg:text-xl"
      length when length <= 20 -> "text-xl max-lg:text-lg"
      _ -> "text-lg max-lg:text-sm"
    end
  end

  attr :details, :list, required: true
  attr :warned, :list, default: [], doc: "the indexes of the steps with a warning"

  # The bars only show each step's share; its fuel is in the text next to it
  defp fuel_by_step(assigns) do
    assigns =
      assign(assigns, :max, assigns.details |> Enum.map(& &1.fuel) |> Enum.max() |> max(1))

    ~H"""
    <%!-- Below lg it is part of the bar, opened by #fuel-by-step-toggle --%>
    <div
      id="fuel-by-step-panel"
      class="border-t border-base-300 max-lg:hidden max-lg:max-h-[45dvh] max-lg:overflow-y-auto"
    >
      <p class="px-6 pt-4 text-xs font-semibold tracking-wide text-base-content/80 uppercase max-lg:px-4">
        Fuel by step
      </p>
      <ul id="fuel-by-step" class="space-y-3 px-6 pt-3 pb-5 max-lg:px-4">
        <li :for={{detail, index} <- Enum.with_index(@details, 1)}>
          <%!-- A long fuel wraps below the label instead of cutting it --%>
          <div class="flex flex-wrap items-baseline justify-between gap-x-3 text-sm">
            <span data-role="label" class="text-base-content/80">
              <.icon
                :if={(index - 1) in @warned}
                name="hero-exclamation-triangle-micro"
                class="-mt-0.5 me-1 size-3.5 text-warning"
              />{index} · {action_on(detail.action, detail.planet)}
            </span>
            <span data-role="fuel" class="ms-auto font-semibold tabular-nums">
              {format_kg(detail.fuel)}
            </span>
          </div>
          <progress
            class="progress progress-primary mt-1 h-1.5 w-full"
            value={detail.fuel}
            max={@max}
            aria-hidden="true"
          />
        </li>
      </ul>
    </div>
    """
  end

  attr :missing, :list, required: true

  # Only the first missing thing is spelled out, with a count of the others
  defp fuel_pending(assigns) do
    ~H"""
    <div
      id="fuel-pending"
      class="stat-desc mt-1 text-sm whitespace-normal text-base-content/80 max-lg:hidden"
    >
      <%= case @missing do %>
        <% [first | rest] -> %>
          <p>
            {missing_sentence(first)}<span :if={rest != []} class="text-base-content/60"> · {length(
              rest
            )} more</span>
          </p>
        <% [] -> %>
          <p>Fix the errors in the flight path</p>
      <% end %>
    </div>
    """
  end

  defp missing_sentence(:first_step), do: "Add the first step"
  defp missing_sentence({:mass, :blank}), do: "Enter the spacecraft mass"
  defp missing_sentence({:mass, :invalid}), do: "Enter a valid spacecraft mass"

  defp missing_sentence({:step, index, fields}),
    do: "Choose #{Enum.map_join(fields, " and ", &with_article/1)} for step #{index + 1}"

  defp with_article(:action), do: "an action"
  defp with_article(:planet), do: "a planet"

  defp missing_label([]), do: "Complete the mission"
  defp missing_label([first]), do: short_missing(first)
  defp missing_label([first | rest]), do: "#{short_missing(first)} · +#{length(rest)}"

  defp short_missing(:first_step), do: "First step"
  defp short_missing({:mass, _reason}), do: "Spacecraft mass"

  defp short_missing({:step, index, fields}),
    do: "Step #{index + 1}: #{Enum.map_join(fields, " and ", &Atom.to_string/1)}"

  # Steps are numbered from 1, so the previous step's number is this step's index
  defp warned_sentence([index]), do: "Step #{index + 1} can't follow step #{index}."
  defp warned_sentence(warned), do: "#{length(warned)} steps can't follow the previous one."

  defp warned_label([index]), do: "Step #{index + 1}"
  defp warned_label(warned), do: "#{length(warned)} steps"

  defp steps_label(1), do: "1 step"
  defp steps_label(count), do: "#{count} steps"

  @doc """
  Formats a mass in kilograms with thousands separators, as in "28,801 kg".
  """
  def format_kg(kg), do: format_number(kg) <> " kg"

  @doc """
  Formats an integer with thousands separators, as in "28,801".
  """
  def format_number(number) do
    Regex.replace(~r/\B(?=(\d{3})+(?!\d))/, Integer.to_string(number), ",")
  end
end
