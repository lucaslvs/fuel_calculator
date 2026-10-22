defmodule FuelCalculator.Mission do
  @moduledoc """
  A spacecraft mass and the flight path it flies, validated from user input.

  Steps can be added, removed and reordered through the `steps_sort` and
  `steps_drop` parameters (see `Ecto.Changeset.cast_embed/3`).
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias FuelCalculator.Fuel
  alias FuelCalculator.Mission.Step

  # Fuel is calculated in floats. Up to this mass and number of steps, the results
  # match exact integer arithmetic even on the heaviest path (Earth launches only),
  # where a 16th step is already off by 2 kg.
  @max_mass 1_000_000_000_000
  @max_steps 15

  @type t :: %__MODULE__{mass: pos_integer() | nil, steps: [Step.t()]}
  @type fuel :: %{total: non_neg_integer(), steps: [non_neg_integer()]}

  @primary_key false
  embedded_schema do
    field :mass, :integer
    embeds_many :steps, Step, on_replace: :delete
  end

  @doc """
  Casts and validates the mass and the flight path steps of a mission.

  An empty flight path is valid and requires no fuel. A flight path has at most
  `max_steps/0` steps.
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(mission, attrs) do
    mission
    |> cast(attrs, [:mass])
    |> validate_required([:mass])
    |> validate_number(:mass, greater_than: 0, less_than_or_equal_to: @max_mass)
    |> cast_steps()
    |> validate_untouched_steps()
  end

  # Casting builds a changeset for every step in the params, so oversized params are
  # rejected before casting. cast/3 has already turned the params keys into strings.
  defp cast_steps(%{params: params} = changeset) do
    if max(param_length(params["steps"]), param_length(params["steps_sort"])) > @max_steps do
      add_error(changeset, :steps, "should have at most %{count} item(s)",
        count: @max_steps,
        validation: :length,
        kind: :max,
        type: :list
      )
    else
      changeset
      |> cast_embed(:steps, sort_param: :steps_sort, drop_param: :steps_drop)
      |> validate_length(:steps, max: @max_steps)
    end
  end

  defp param_length(steps) when is_map(steps), do: map_size(steps)
  defp param_length(steps) when is_list(steps), do: length(steps)
  defp param_length(_steps), do: 0

  # cast_embed/3 only validates the steps given in the params, so steps already in
  # the mission that the params leave untouched would otherwise count as valid.
  defp validate_untouched_steps(changeset) do
    cond do
      get_change(changeset, :steps) -> changeset
      Enum.all?(changeset.data.steps, &Step.changeset(&1, %{}).valid?) -> changeset
      true -> add_error(changeset, :steps, "is invalid")
    end
  end

  @doc """
  Returns the largest spacecraft mass, in kg.
  """
  @spec max_mass() :: pos_integer()
  def max_mass, do: @max_mass

  @doc """
  Returns the largest number of steps in a flight path.
  """
  @spec max_steps() :: pos_integer()
  def max_steps, do: @max_steps

  @doc """
  Validates a mission `changeset` and returns the fuel the mission requires.
  """
  @spec calculate(Ecto.Changeset.t()) :: {:ok, fuel()} | {:error, Ecto.Changeset.t()}
  def calculate(%Ecto.Changeset{} = changeset) do
    with {:ok, mission} <- apply_action(changeset, :validate) do
      {:ok, fuel(mission)}
    end
  end

  @doc """
  Returns the fuel required to fly a valid `mission`: the total and the fuel
  of each step, in the order of the flight path.

  ## Examples

      iex> alias FuelCalculator.Mission.Step
      iex> FuelCalculator.Mission.fuel(%FuelCalculator.Mission{
      ...>   mass: 28801,
      ...>   steps: [
      ...>     %Step{action: :launch, planet: :earth},
      ...>     %Step{action: :land, planet: :moon},
      ...>     %Step{action: :launch, planet: :moon},
      ...>     %Step{action: :land, planet: :earth}
      ...>   ]
      ...> })
      %{total: 51898, steps: [32988, 2462, 3001, 13447]}

  """
  @spec fuel(t()) :: fuel()
  def fuel(%__MODULE__{mass: mass, steps: steps}) do
    step_fuels = Fuel.breakdown(mass, Enum.map(steps, &{&1.action, &1.planet}))
    %{total: Enum.sum(step_fuels), steps: step_fuels}
  end
end
