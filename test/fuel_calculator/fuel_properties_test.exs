defmodule FuelCalculator.FuelPropertiesTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias FuelCalculator.Fuel
  alias FuelCalculator.Planet

  # The constants as the challenge writes them, read as exact fractions
  @gravities %{earth: "9.807", moon: "1.62", mars: "3.711"}
  @formulas %{launch: {"0.042", 33}, land: {"0.033", 42}}

  property "never needs less fuel for more mass" do
    check all mass <- mass(),
              extra <- positive_integer(),
              path <- path() do
      assert Fuel.total(mass, path) <= Fuel.total(mass + extra, path)
    end
  end

  property "matches an exact model of the challenge's formulas" do
    check all mass <- mass(), path <- path() do
      assert Fuel.total(mass, path) == exact_total(mass, path)
    end
  end

  # Masses across the whole range are almost all huge, so small ones are drawn apart
  defp mass, do: one_of([integer(1..100_000), integer(1..1_000_000_000_000)])

  defp path do
    list_of({member_of([:launch, :land]), member_of(Planet.all())}, max_length: 15)
  end

  # Each step carries the fuel of the later steps, so the path is folded from the end
  defp exact_total(mass, path) do
    List.foldr(path, 0, fn {action, planet}, carried ->
      carried + exact_step_fuel(mass + carried, action, planet)
    end)
  end

  defp exact_step_fuel(mass, action, planet) do
    {gravity, gravity_scale} = fraction(@gravities[planet])
    {factor, offset} = @formulas[action]
    {factor, factor_scale} = fraction(factor)
    scale = gravity_scale * factor_scale

    case Integer.floor_div(mass * gravity * factor - offset * scale, scale) do
      fuel when fuel > 0 -> fuel + exact_step_fuel(fuel, action, planet)
      _ -> 0
    end
  end

  defp fraction(decimal) do
    [whole, digits] = String.split(decimal, ".")
    {String.to_integer(whole <> digits), 10 ** String.length(digits)}
  end
end
