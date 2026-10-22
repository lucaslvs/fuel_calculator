defmodule FuelCalculator.Fuel do
  @moduledoc """
  Calculates the fuel required to launch from and land on planets.

  Fuel adds weight to the ship, so every amount of fuel requires more fuel,
  until the additional amount is zero or negative.
  """

  alias FuelCalculator.Planet

  @type action :: :launch | :land
  @type step :: {action(), Planet.t()}

  @doc """
  Returns the fuel required for a single `action` on `planet` with `mass`,
  including the fuel needed to carry that fuel.

  ## Examples

      iex> FuelCalculator.Fuel.step_fuel(28801, :land, :earth)
      13447

  """
  @spec step_fuel(pos_integer(), action(), Planet.t()) :: non_neg_integer()
  def step_fuel(mass, action, planet)
      when is_integer(mass) and mass > 0 and action in [:launch, :land] do
    case base_fuel(mass, action, Planet.gravity(planet)) do
      fuel when fuel > 0 -> fuel + step_fuel(fuel, action, planet)
      _ -> 0
    end
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
    path
    |> Enum.reverse()
    |> Enum.map_reduce(0, fn {action, planet}, carried ->
      fuel = step_fuel(mass + carried, action, planet)
      {fuel, carried + fuel}
    end)
    |> elem(0)
    |> Enum.reverse()
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

  defp base_fuel(mass, :launch, gravity), do: floor(mass * gravity * 0.042 - 33)
  defp base_fuel(mass, :land, gravity), do: floor(mass * gravity * 0.033 - 42)
end
