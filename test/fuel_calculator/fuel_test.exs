defmodule FuelCalculator.FuelTest do
  use ExUnit.Case, async: true

  alias FuelCalculator.Fuel

  doctest Fuel

  describe "step_fuel/3" do
    test "adds fuel for the fuel until the additional amount is not positive" do
      assert Fuel.step_fuel(28_801, :land, :earth) == 9278 + 2960 + 915 + 254 + 40
    end

    test "uses the launch formula" do
      assert Fuel.step_fuel(28_801, :launch, :earth) == 19_772
    end

    test "returns zero when the mass needs no fuel" do
      assert Fuel.step_fuel(80, :launch, :earth) == 0
    end

    test "stops when the fuel itself needs no more fuel" do
      assert Fuel.step_fuel(83, :launch, :earth) == 1
    end

    test "rejects a mass that is not positive" do
      assert_raise FunctionClauseError, fn -> Fuel.step_fuel(0, :land, :earth) end
      assert_raise FunctionClauseError, fn -> Fuel.step_fuel(-1, :land, :earth) end
    end
  end

  describe "total/2" do
    test "calculates the Apollo 11 mission" do
      path = [launch: :earth, land: :moon, launch: :moon, land: :earth]

      assert Fuel.total(28_801, path) == 51_898
    end

    test "calculates the Mars mission" do
      path = [launch: :earth, land: :mars, launch: :mars, land: :earth]

      assert Fuel.total(14_606, path) == 33_388
    end

    test "calculates the passenger ship mission" do
      path = [
        launch: :earth,
        land: :moon,
        launch: :moon,
        land: :mars,
        launch: :mars,
        land: :earth
      ]

      assert Fuel.total(75_432, path) == 212_161
    end

    test "carries the fuel for later steps as weight" do
      path = [launch: :earth, land: :moon, launch: :moon, land: :earth]

      refute Fuel.total(28_801, Enum.reverse(path)) == Fuel.total(28_801, path)
    end

    test "requires no fuel for an empty path" do
      assert Fuel.total(28_801, []) == 0
    end

    test "rejects a mass that is not positive" do
      assert_raise FunctionClauseError, fn -> Fuel.total(0, []) end
      assert_raise FunctionClauseError, fn -> Fuel.total(-1, []) end
    end
  end
end
