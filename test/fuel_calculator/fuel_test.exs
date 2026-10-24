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

  describe "iterations/3" do
    test "returns the fuel for the mass, then for each amount of fuel" do
      assert Fuel.iterations(28_801, :land, :earth) == [9278, 2960, 915, 254, 40]
    end

    test "returns no fuel when the mass needs none" do
      assert Fuel.iterations(80, :launch, :earth) == []
    end

    test "stops when the fuel itself needs no more fuel" do
      assert Fuel.iterations(83, :launch, :earth) == [1]
    end

    # In floats, 601_183_387_170 * 9.807 * 0.042 - 33 rounds up to an integer,
    # one hair above the exact 247_623_830_041.99998
    test "rounds down the exact fuel near the largest mass" do
      assert [247_623_830_041, 101_994_769_817 | _] =
               Fuel.iterations(601_183_387_170, :launch, :earth)
    end

    test "rejects a mass that is not positive" do
      assert_raise FunctionClauseError, fn -> Fuel.iterations(0, :land, :earth) end
      assert_raise FunctionClauseError, fn -> Fuel.iterations(-1, :land, :earth) end
    end
  end

  describe "formula/1" do
    test "returns the factor and the offset of each action" do
      assert Fuel.formula(:launch) == {0.042, 33}
      assert Fuel.formula(:land) == {0.033, 42}
    end
  end

  describe "explain/2" do
    test "returns the mass and the fuel iterations of each Apollo 11 step" do
      path = [launch: :earth, land: :moon, launch: :moon, land: :earth]

      assert Fuel.explain(28_801, path) == [
               %{
                 action: :launch,
                 planet: :earth,
                 mass: 47_711,
                 iterations: [19_618, 8047, 3281, 1318, 509, 176, 39]
               },
               %{action: :land, planet: :moon, mass: 45_249, iterations: [2377, 85]},
               %{action: :launch, planet: :moon, mass: 42_248, iterations: [2841, 160]},
               %{
                 action: :land,
                 planet: :earth,
                 mass: 28_801,
                 iterations: [9278, 2960, 915, 254, 40]
               }
             ]
    end

    test "returns no steps for an empty path" do
      assert Fuel.explain(28_801, []) == []
    end

    test "rejects a mass that is not positive" do
      assert_raise FunctionClauseError, fn -> Fuel.explain(0, []) end
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

    # The largest mission a user can enter, with the exact integer results
    test "calculates the heaviest missions" do
      assert Fuel.breakdown(1_000_000_000_000, launch: :earth, land: :earth) ==
               [1_035_490_598_312, 478_482_897_826]

      assert Fuel.total(1_000_000_000_000, List.duplicate({:launch, :earth}, 15)) ==
               2_870_877_069_360_685
    end

    test "rejects a mass that is not positive" do
      assert_raise FunctionClauseError, fn -> Fuel.total(0, []) end
      assert_raise FunctionClauseError, fn -> Fuel.total(-1, []) end
    end
  end
end
