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

    test "returns zero when the base fuel is exactly zero" do
      assert Fuel.step_fuel(81, :launch, :earth) == 0
    end

    test "stops when the fuel itself needs no more fuel" do
      assert Fuel.step_fuel(83, :launch, :earth) == 1
    end

    test "rejects a mass that is not positive" do
      assert_raise FunctionClauseError, fn -> Fuel.step_fuel(0, :land, :earth) end
      assert_raise FunctionClauseError, fn -> Fuel.step_fuel(-1, :land, :earth) end
    end
  end

  describe "breakdown/2" do
    test "returns the fuel of each Apollo 11 step" do
      path = [launch: :earth, land: :moon, launch: :moon, land: :earth]

      assert Fuel.breakdown(28_801, path) == [32_988, 2462, 3001, 13_447]
    end

    test "adds up to the total of each mission" do
      for {mass, path} <- [
            {28_801, [launch: :earth, land: :moon, launch: :moon, land: :earth]},
            {14_606, [launch: :earth, land: :mars, launch: :mars, land: :earth]},
            {75_432,
             [
               launch: :earth,
               land: :moon,
               launch: :moon,
               land: :mars,
               launch: :mars,
               land: :earth
             ]}
          ] do
        assert mass |> Fuel.breakdown(path) |> Enum.sum() == Fuel.total(mass, path)
      end
    end

    test "returns no steps for an empty path" do
      assert Fuel.breakdown(28_801, []) == []
    end

    test "rejects a mass that is not positive" do
      assert_raise FunctionClauseError, fn -> Fuel.breakdown(0, []) end
      assert_raise FunctionClauseError, fn -> Fuel.breakdown(-1, []) end
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

    test "requires no fuel for an empty path" do
      assert Fuel.total(28_801, []) == 0
    end

    test "rejects a mass that is not positive" do
      assert_raise FunctionClauseError, fn -> Fuel.total(0, []) end
      assert_raise FunctionClauseError, fn -> Fuel.total(-1, []) end
    end
  end
end
