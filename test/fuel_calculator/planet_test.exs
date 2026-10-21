defmodule FuelCalculator.PlanetTest do
  use ExUnit.Case, async: true

  alias FuelCalculator.Planet

  doctest Planet

  describe "all/0" do
    test "lists the supported planets in display order" do
      assert Planet.all() == [:earth, :moon, :mars]
    end
  end

  describe "gravity/1" do
    test "returns the surface gravity of each planet" do
      assert Planet.gravity(:earth) == 9.807
      assert Planet.gravity(:moon) == 1.62
      assert Planet.gravity(:mars) == 3.711
    end

    test "is defined for every supported planet" do
      for planet <- Planet.all() do
        assert is_float(Planet.gravity(planet))
      end
    end
  end
end
