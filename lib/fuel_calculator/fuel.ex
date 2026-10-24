defmodule FuelCalculator.Fuel do
  @moduledoc """
  Calculates the fuel required to launch from and land on planets.

  Fuel adds weight to the ship, so every amount of fuel requires more fuel,
  until the additional amount is zero or negative.
  """

  alias FuelCalculator.Planet

  @actions [:launch, :land]

  @type action :: :launch | :land
  @type step :: {action(), Planet.t()}

  @type detail :: %{
          action: action(),
          planet: Planet.t(),
          mass: pos_integer(),
          iterations: [pos_integer()],
          fuel: non_neg_integer()
        }

  @doc """
  Returns the supported actions, in display order.

  ## Examples

      iex> FuelCalculator.Fuel.actions()
      [:launch, :land]

  """
  @spec actions() :: [action()]
  def actions, do: @actions

  @doc """
  Returns the fuel required for a single `action` on `planet` with `mass`,
  including the fuel needed to carry that fuel.

  ## Examples

      iex> FuelCalculator.Fuel.step_fuel(28801, :land, :earth)
      13447

  """
  @spec step_fuel(pos_integer(), action(), Planet.t()) :: non_neg_integer()
  def step_fuel(mass, action, planet), do: mass |> iterations(action, planet) |> Enum.sum()

  @doc """
  Returns the fuel required for `mass`, then for each amount of fuel in turn,
  until the additional amount is zero or negative. Their sum is `step_fuel/3`.

  ## Examples

      iex> FuelCalculator.Fuel.iterations(28801, :land, :earth)
      [9278, 2960, 915, 254, 40]

  """
  @spec iterations(pos_integer(), action(), Planet.t()) :: [pos_integer()]
  def iterations(mass, action, planet)
      when is_integer(mass) and mass > 0 and action in @actions do
    case base_fuel(mass, action, planet) do
      fuel when fuel > 0 -> [fuel | iterations(fuel, action, planet)]
      _ -> []
    end
  end

  @doc """
  Returns the factor and the offset of the formula for `action`: the fuel for a
  mass is `mass * gravity * factor - offset`, rounded down.

  ## Examples

      iex> FuelCalculator.Fuel.formula(:land)
      {0.033, 42}

  """
  @spec formula(action()) :: {float(), pos_integer()}
  def formula(action) do
    {factor, offset} = formula_thousandths(action)
    {factor / 1000, offset}
  end

  @doc """
  Returns how the fuel of each step is calculated when flying `mass` along
  `path`, in the order of the path: the mass the step carries, which includes
  the fuel for the later steps, the `iterations/3` for that mass and their sum,
  the step's fuel.

  ## Examples

      iex> FuelCalculator.Fuel.explain(28801, [{:launch, :moon}, {:land, :earth}])
      [
        %{action: :launch, planet: :moon, mass: 42248, iterations: [2841, 160], fuel: 3001},
        %{
          action: :land,
          planet: :earth,
          mass: 28801,
          iterations: [9278, 2960, 915, 254, 40],
          fuel: 13447
        }
      ]

  """
  @spec explain(pos_integer(), [step()]) :: [detail()]
  def explain(mass, path) when is_integer(mass) and mass > 0 and is_list(path) do
    path
    |> Enum.reverse()
    |> Enum.map_reduce(0, fn {action, planet}, carried ->
      iterations = iterations(mass + carried, action, planet)
      fuel = Enum.sum(iterations)

      detail = %{
        action: action,
        planet: planet,
        mass: mass + carried,
        iterations: iterations,
        fuel: fuel
      }

      {detail, carried + fuel}
    end)
    |> elem(0)
    |> Enum.reverse()
  end

  @doc """
  Returns the fuel required for each step when flying `mass` along `path`,
  in the order of the path.

  Steps are calculated from last to first, since the fuel for the later
  steps is carried as weight during the earlier ones.

  ## Examples

      iex> FuelCalculator.Fuel.breakdown(28801, [
      ...>   {:launch, :earth},
      ...>   {:land, :moon},
      ...>   {:launch, :moon},
      ...>   {:land, :earth}
      ...> ])
      [32988, 2462, 3001, 13447]

  """
  @spec breakdown(pos_integer(), [step()]) :: [non_neg_integer()]
  def breakdown(mass, path) when is_integer(mass) and mass > 0 and is_list(path) do
    for %{fuel: fuel} <- explain(mass, path), do: fuel
  end

  @doc """
  Returns the total fuel required to fly `mass` along `path`.

  ## Examples

      iex> FuelCalculator.Fuel.total(28801, [
      ...>   {:launch, :earth},
      ...>   {:land, :moon},
      ...>   {:launch, :moon},
      ...>   {:land, :earth}
      ...> ])
      51898

  """
  @spec total(pos_integer(), [step()]) :: non_neg_integer()
  def total(mass, path) when is_integer(mass) and mass > 0 and is_list(path) do
    mass |> breakdown(path) |> Enum.sum()
  end

  # Gravity and factor are both in thousandths, so the product is in millionths
  defp base_fuel(mass, action, planet) do
    {factor, offset} = formula_thousandths(action)
    gravity = Planet.gravity_thousandths(planet)
    Integer.floor_div(mass * gravity * factor - offset * 1_000_000, 1_000_000)
  end

  defp formula_thousandths(:launch), do: {42, 33}
  defp formula_thousandths(:land), do: {33, 42}
end
