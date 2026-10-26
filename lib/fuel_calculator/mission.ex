defmodule FuelCalculator.Mission do
  @moduledoc """
  A spacecraft mass and the flight path it flies, validated from user input.

  Steps can be added, removed and reordered through the `steps_sort` and
  `steps_drop` parameters (see `Ecto.Changeset.cast_embed/3`).
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias FuelCalculator.Fuel
  alias FuelCalculator.Mission.Mass
  alias FuelCalculator.Mission.Step
  alias FuelCalculator.Planet

  # Bounds for user input. The fuel is calculated with integers, so it is exact
  # for any mass and path.
  @max_mass 1_000_000_000_000
  @max_steps 15

  @type t :: %__MODULE__{mass: pos_integer() | nil, steps: [Step.t()]}
  @type fuel :: %{total: non_neg_integer(), details: [Fuel.detail()]}

  @typedoc """
  Something a mission lacks before its fuel can be calculated: a mass, blank or
  invalid, or the fields of an incomplete step (by index).
  """
  @type missing :: {:mass, :blank | :invalid} | {:step, non_neg_integer(), [:action | :planet]}

  @primary_key false
  embedded_schema do
    field :mass, Mass
    embeds_many :steps, Step, on_replace: :delete
  end

  @doc """
  Casts and validates the mass and the flight path steps of a mission. The mass
  may group its digits with commas.

  An empty flight path is valid and requires no fuel. A flight path has at most
  `max_steps/0` steps.
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(mission, attrs) do
    mission
    |> cast(attrs, [:mass], message: fn :mass, _meta -> "must be a whole number" end)
    |> validate_required([:mass])
    |> validate_number(:mass, greater_than: 0, less_than_or_equal_to: @max_mass)
    |> cast_steps()
  end

  # Casting builds a changeset for every step in the params, which the changeset keeps,
  # so oversized params are rejected before casting, and it raises on a step given as a
  # list instead of a map.
  # cast/3 has already turned the params keys into strings.
  defp cast_steps(%{params: params} = changeset) do
    steps = params["steps"]

    cond do
      oversized?(params) ->
        add_error(changeset, :steps, "should have at most %{count} item(s)",
          count: @max_steps,
          validation: :length,
          kind: :max,
          type: :list
        )

      Enum.any?(step_params(steps), &is_list/1) ->
        add_error(changeset, :steps, "is invalid")

      true ->
        changeset
        |> cast_embed(:steps, sort_param: :steps_sort, drop_param: :steps_drop)
        |> validate_length(:steps, max: @max_steps)
    end
  end

  defp oversized?(params) do
    Enum.any?(~w(steps steps_sort steps_drop), &(param_length(params[&1]) > @max_steps))
  end

  defp param_length(steps) when is_map(steps), do: map_size(steps)
  defp param_length(steps) when is_list(steps), do: length(steps)
  defp param_length(_steps), do: 0

  defp step_params(steps) when is_map(steps), do: Map.values(steps)
  defp step_params(steps) when is_list(steps), do: steps
  defp step_params(_steps), do: []

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
  Returns what a mission `changeset` lacks before its fuel can be calculated, in the
  order of the form: the mass, then each incomplete step.

  It is empty for a complete mission, and also when only the flight path as a whole
  is invalid (too many steps).
  """
  @spec missing(Ecto.Changeset.t()) :: [missing()]
  def missing(%Ecto.Changeset{} = changeset) do
    mass_missing(changeset) ++ steps_missing(changeset)
  end

  defp mass_missing(%{errors: errors}) do
    case Keyword.get(errors, :mass) do
      nil ->
        []

      {_message, opts} ->
        [{:mass, if(opts[:validation] == :required, do: :blank, else: :invalid)}]
    end
  end

  defp steps_missing(changeset) do
    changeset
    |> get_embed(:steps, :changeset)
    |> Enum.with_index()
    |> Enum.flat_map(&step_missing/1)
  end

  defp step_missing({%{errors: errors}, index}) do
    case for(field <- [:action, :planet], Keyword.has_key?(errors, field), do: field) do
      [] -> []
      fields -> [{:step, index, fields}]
    end
  end

  @doc """
  Returns the flight path of a `mission`, or of a mission changeset as entered so
  far: the action and planet of each step, with `nil` for one not chosen or invalid.

  ## Examples

      iex> alias FuelCalculator.Mission
      iex> Mission.changeset(%Mission{}, %{
      ...>   "steps" => [%{"action" => "launch", "planet" => "earth"}, %{"action" => "land"}]
      ...> })
      ...> |> Mission.path()
      [{:launch, :earth}, {:land, nil}]

  """
  @spec path(t() | Ecto.Changeset.t()) :: [{Fuel.action() | nil, Planet.t() | nil}]
  def path(%Ecto.Changeset{} = changeset), do: changeset |> apply_changes() |> path()
  def path(%__MODULE__{steps: steps}), do: Enum.map(steps, &{&1.action, &1.planet})

  @doc """
  Returns the fuel required to fly a valid `mission`: the total and, for each
  step in the order of the flight path, its fuel and how it is calculated (see
  `FuelCalculator.Fuel.explain/2`).

  ## Examples

      iex> alias FuelCalculator.Mission.Step
      iex> fuel = FuelCalculator.Mission.fuel(%FuelCalculator.Mission{
      ...>   mass: 28801,
      ...>   steps: [
      ...>     %Step{action: :launch, planet: :earth},
      ...>     %Step{action: :land, planet: :moon},
      ...>     %Step{action: :launch, planet: :moon},
      ...>     %Step{action: :land, planet: :earth}
      ...>   ]
      ...> })
      iex> {fuel.total, Enum.map(fuel.details, & &1.fuel)}
      {51898, [32988, 2462, 3001, 13447]}

  """
  @spec fuel(t()) :: fuel()
  def fuel(%__MODULE__{mass: mass} = mission) do
    details = Fuel.explain(mass, path(mission))
    %{total: Enum.sum_by(details, & &1.fuel), details: details}
  end
end
