defmodule FuelCalculatorWeb.MissionComponents do
  @moduledoc """
  Components of the mission page: the example missions, the flight path and the fuel
  summary.

  The flight path components render inside `FuelCalculatorWeb.MissionLive`'s form and
  send its `steps_sort`, `steps_drop` and `steps_swap` params.
  """

  use FuelCalculatorWeb, :html

  @doc """
  Renders a button per example mission, which sends `load_example` with its id.
  """
  attr :examples, :list,
    required: true,
    doc: "the example missions, as `{id, label, mass, flight path}` tuples"

  def example_buttons(assigns) do
    ~H"""
    <div class="flex flex-wrap items-center gap-2">
      <span class="text-sm text-base-content/70">Try an example:</span>
      <button
        :for={{id, label, _mass, _path} <- @examples}
        id={"example-#{id}"}
        type="button"
        phx-click="load_example"
        phx-value-id={id}
        class="btn btn-soft btn-sm"
      >
        {label}
      </button>
    </div>
    """
  end

  @doc """
  Renders the flight path fieldset: a row per step, the steps' errors and the button
  that adds a step.
  """
  attr :field, Phoenix.HTML.FormField, required: true, doc: "the mission's steps field"
  attr :step_count, :integer, required: true
  attr :max_steps, :integer, required: true
  attr :fuel, :map, default: nil, doc: "the mission's fuel, or nil while it is invalid"
  attr :action_options, :list, required: true
  attr :planet_options, :list, required: true

  def flight_path(assigns) do
    ~H"""
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
        <.inputs_for :let={step} field={@field}>
          <.step_row
            step={step}
            step_count={@step_count}
            fuel={@fuel && Enum.at(@fuel.steps, step.index)}
            action_options={@action_options}
            planet_options={@planet_options}
          />
        </.inputs_for>
      </div>

      <input type="hidden" name="mission[steps_drop][]" />

      <div :if={@field.errors != []} id="steps-errors">
        <p
          :for={msg <- Enum.map(@field.errors, &translate_error/1)}
          class="flex items-center gap-2 text-sm text-error"
        >
          <.icon name="hero-exclamation-circle" class="size-5" />
          {msg}
        </p>
      </div>

      <.button
        id="add-step"
        type="button"
        name="mission[steps_sort][]"
        value="new"
        phx-click={JS.dispatch("change")}
        disabled={@step_count >= @max_steps}
        class="btn btn-soft btn-primary mt-2"
      >
        <.icon name="hero-plus" class="size-5" /> Add step
      </.button>
      <p :if={@step_count >= @max_steps} id="step-limit" class="label">
        A flight path has at most {@max_steps} steps.
      </p>
    </fieldset>
    """
  end

  @doc """
  Renders a step of the flight path: its number, action, planet and fuel, and the
  buttons that move and remove it.
  """
  attr :step, Phoenix.HTML.Form, required: true, doc: "the step's form, from `inputs_for`"
  attr :step_count, :integer, required: true
  attr :fuel, :integer, default: nil, doc: "the step's fuel, or nil while the mission is invalid"
  attr :action_options, :list, required: true
  attr :planet_options, :list, required: true

  def step_row(assigns) do
    ~H"""
    <div
      id={"step-#{@step.index}"}
      class="list-row items-start gap-2 px-0 py-2 motion-safe:animate-fade-in sm:gap-3"
    >
      <span
        data-role="step-number"
        class="w-8 pt-1 text-center text-2xl font-thin tabular-nums opacity-40"
      >
        {@step.index + 1}
      </span>
      <div class="list-col-grow flex flex-wrap gap-x-2">
        <div class="flex-none">
          <.action_toggle
            field={@step[:action]}
            label={"Step #{@step.index + 1} action"}
            options={@action_options}
          />
        </div>
        <div class="min-w-28 flex-1">
          <.input
            field={@step[:planet]}
            type="select"
            prompt="Planet"
            options={@planet_options}
            aria-label={"Step #{@step.index + 1} planet"}
          />
        </div>
        <%!-- Keeps its width while the mission is invalid, so the selects don't jump --%>
        <div class="flex w-full items-center sm:mb-2 sm:w-auto sm:min-w-28 sm:justify-end sm:py-1">
          <span
            :if={@fuel}
            id={"step-fuel-#{@step.index}"}
            class="badge badge-soft badge-primary mb-2 tabular-nums sm:mb-0"
          >
            {format_kg(@fuel)}
          </span>
        </div>
      </div>
      <div class="join join-vertical mt-1 sm:join-horizontal">
        <.button
          id={"move-step-up-#{@step.index}"}
          type="button"
          name="mission[steps_swap]"
          value={@step.index - 1}
          phx-click={JS.dispatch("change")}
          disabled={@step.index == 0}
          class="btn btn-ghost btn-sm btn-square join-item sm:btn-md"
          aria-label={"Move step #{@step.index + 1} up"}
        >
          <.icon name="hero-chevron-up" class="size-5" />
        </.button>
        <.button
          id={"move-step-down-#{@step.index}"}
          type="button"
          name="mission[steps_swap]"
          value={@step.index}
          phx-click={JS.dispatch("change")}
          disabled={@step.index == @step_count - 1}
          class="btn btn-ghost btn-sm btn-square join-item sm:btn-md"
          aria-label={"Move step #{@step.index + 1} down"}
        >
          <.icon name="hero-chevron-down" class="size-5" />
        </.button>
        <.button
          id={"remove-step-#{@step.index}"}
          type="button"
          name="mission[steps_drop][]"
          value={@step.index}
          phx-click={JS.dispatch("change")}
          class="btn btn-ghost btn-sm btn-square join-item hover:text-error sm:btn-md"
          aria-label={"Remove step #{@step.index + 1}"}
        >
          <.icon name="hero-x-mark" class="size-5" />
        </.button>
      </div>
      <input type="hidden" name="mission[steps_sort][]" value={@step.index} />
    </div>
    """
  end

  @doc """
  Renders a step's action as a group of radio buttons, one per action.

  While no action is checked the browser sends nothing for the radios, so a hidden
  empty input keeps the action in the params: without it the field never counts as
  used and its error stays hidden, even on submit.
  """
  attr :field, Phoenix.HTML.FormField, required: true, doc: "the step's action field"
  attr :label, :string, required: true, doc: "the accessible name of the group"
  attr :options, :list, required: true, doc: "the actions, as `{label, value}` tuples"

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
      class="fieldset mb-2"
      role="radiogroup"
      aria-invalid={@errors != [] && "true"}
      aria-describedby={@errors != [] && "#{@field.id}-error"}
    >
      <legend class="sr-only">{@label}</legend>
      <input type="hidden" name={@field.name} value="" />
      <div class="join">
        <label
          :for={{label, value} <- @options}
          for={Phoenix.HTML.Form.input_id(@field.form, @field.field, value)}
          class={[
            "btn join-item gap-1",
            "has-focus-visible:outline-2 has-focus-visible:outline-offset-2",
            "has-focus-visible:outline-primary",
            to_string(value) == @checked && "btn-primary",
            @errors != [] && "border-error"
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
  Renders the mission's total fuel, or a dash while the mission is invalid. Screen
  readers announce the total whenever it changes.

  On large screens it is a card that sticks to the top of its column; below that, the
  same element is a compact bar fixed to the bottom of the screen, with the number of
  steps in place of the icon and the description.
  """
  attr :fuel, :map, default: nil, doc: "the mission's fuel, or nil while it is invalid"
  attr :step_count, :integer, required: true

  def fuel_summary(assigns) do
    ~H"""
    <div
      id="fuel-summary"
      class={[
        "stats w-full border border-base-300 bg-base-200",
        "lg:sticky lg:top-6",
        "max-lg:fixed max-lg:inset-x-0 max-lg:bottom-0 max-lg:z-40 max-lg:rounded-none",
        "max-lg:border-x-0 max-lg:border-b-0 max-lg:shadow-lg"
      ]}
    >
      <div class="stat max-lg:px-4 max-lg:py-3">
        <div class="stat-figure text-primary max-lg:hidden">
          <.icon name="hero-fire" class="size-8" />
        </div>
        <div id="fuel-summary-steps" class="stat-figure text-sm text-base-content/70 lg:hidden">
          {if @fuel, do: steps_label(@step_count), else: "Complete the mission"}
        </div>
        <div class="stat-title text-base-content/70">Total fuel required</div>
        <div
          id="total-fuel"
          class="stat-value tabular-nums max-lg:text-2xl"
          aria-live="polite"
          aria-atomic="true"
        >
          <%= if @fuel do %>
            {format_kg(@fuel.total)}
          <% else %>
            <span aria-hidden="true">—</span><span class="sr-only">not available yet</span>
          <% end %>
        </div>
        <div class="stat-desc text-base-content/70 max-lg:hidden">
          {if @fuel,
            do: "Includes the fuel to carry the fuel",
            else: "Enter a mass and complete every step"}
        </div>
      </div>
    </div>
    """
  end

  defp steps_label(1), do: "1 step"
  defp steps_label(count), do: "#{count} steps"

  @doc """
  Formats a mass in kilograms with thousands separators, as in "28,801 kg".
  """
  def format_kg(kg) do
    Regex.replace(~r/\B(?=(\d{3})+(?!\d))/, Integer.to_string(kg), ",") <> " kg"
  end
end
