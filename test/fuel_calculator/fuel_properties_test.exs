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

  property "explains each step as the exact model does" do
    check all mass <- mass(), path <- path() do
      assert Fuel.explain(mass, path) == exact_explain(mass, path)
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
      carried + Enum.sum(exact_iterations(mass + carried, action, planet))
    end)
  end

  defp exact_explain(mass, path) do
    path
    |> List.foldr({[], 0}, fn {action, planet}, {details, carried} ->
      iterations = exact_iterations(mass + carried, action, planet)
      fuel = Enum.sum(iterations)

      detail = %{
        action: action,
        planet: planet,
        mass: mass + carried,
        iterations: iterations,
        fuel: fuel
      }

      {[detail | details], carried + fuel}
    end)
    |> elem(0)
  end

  defp exact_iterations(mass, action, planet) do
    {gravity, gravity_scale} = fraction(@gravities[planet])
    {factor, offset} = @formulas[action]
    {factor, factor_scale} = fraction(factor)
    scale = gravity_scale * factor_scale

    case Integer.floor_div(mass * gravity * factor - offset * scale, scale) do
      fuel when fuel > 0 -> [fuel | exact_iterations(fuel, action, planet)]
      _ -> []
    end
  end

  defp fraction(decimal) do
    [whole, digits] = String.split(decimal, ".")
    {String.to_integer(whole <> digits), 10 ** String.length(digits)}
  end
end
