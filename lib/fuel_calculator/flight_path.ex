defmodule FuelCalculator.FlightPath do
  @moduledoc """
  Checks whether a flight path can be flown in the order given: a spacecraft
  lands after it launches, and launches from the planet it landed on.

  The fuel is calculated for any path, so these are only warnings.
  """

  alias FuelCalculator.Fuel
  alias FuelCalculator.Planet

  @typedoc """
  Why a step can't follow the previous one. `{:launch_elsewhere, launched_from, landed_on}`
  is a launch from another planet than the previous landing.
  """
  @type warning ::
          {:launch_elsewhere, Planet.t(), Planet.t()} | :land_twice | :launch_twice

  @doc """
  Returns a warning or `nil` for each step of `path`, in the order of the path.

  Each step is checked against the previous one, so the first step never has a
  warning, and steps without an action or a planet are skipped.

  ## Examples

      iex> FuelCalculator.FlightPath.warnings([{:launch, :earth}, {:land, :moon}, {:launch, :mars}])
      [nil, nil, {:launch_elsewhere, :mars, :moon}]

  """
  @spec warnings([{Fuel.action() | nil, Planet.t() | nil}]) :: [warning() | nil]
  def warnings(path) when is_list(path) do
    Enum.zip_with([nil | path], path, &warning/2)
  end

  defp warning({:land, landed_on}, {:launch, planet})
       when not is_nil(landed_on) and not is_nil(planet) and landed_on != planet,
       do: {:launch_elsewhere, planet, landed_on}

  defp warning({:land, landed_on}, {:land, planet})
       when not is_nil(landed_on) and not is_nil(planet),
       do: :land_twice

  defp warning({:launch, launched_from}, {:launch, planet})
       when not is_nil(launched_from) and not is_nil(planet),
       do: :launch_twice

  defp warning(_previous, _step), do: nil
end
