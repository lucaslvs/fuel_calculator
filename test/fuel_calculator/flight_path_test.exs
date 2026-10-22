defmodule FuelCalculator.FlightPathTest do
  use ExUnit.Case, async: true

  alias FuelCalculator.FlightPath

  doctest FlightPath

  describe "warnings/1" do
    test "finds nothing wrong in the missions of the challenge" do
      for path <- [
            [launch: :earth, land: :moon, launch: :moon, land: :earth],
            [launch: :earth, land: :mars, launch: :mars, land: :earth],
            [launch: :earth, land: :moon, launch: :moon, land: :mars, launch: :mars, land: :earth]
          ] do
        assert Enum.all?(FlightPath.warnings(path), &is_nil/1)
      end
    end

    test "warns about a launch from another planet than the last landing" do
      assert FlightPath.warnings(launch: :earth, land: :moon, launch: :mars) ==
               [nil, nil, {:launch_elsewhere, :mars, :moon}]
    end

    test "warns about a landing right after another landing" do
      assert FlightPath.warnings(launch: :earth, land: :earth, land: :mars) ==
               [nil, nil, :land_twice]
    end

    test "warns about a launch right after another launch" do
      assert FlightPath.warnings(launch: :earth, launch: :earth) == [nil, :launch_twice]
      assert FlightPath.warnings(launch: :earth, launch: :mars) == [nil, :launch_twice]
    end

    test "accepts a path that starts with a landing or ends with a launch" do
      assert FlightPath.warnings(land: :moon, launch: :moon) == [nil, nil]
      assert FlightPath.warnings(launch: :earth) == [nil]
    end

    test "accepts a landing back on the planet of the launch" do
      assert FlightPath.warnings(launch: :earth, land: :earth) == [nil, nil]
    end

    test "returns no warnings for an empty path" do
      assert FlightPath.warnings([]) == []
    end

    test "skips incomplete steps and the steps after them" do
      assert FlightPath.warnings([{:land, :moon}, {:launch, nil}, {:launch, :mars}]) ==
               [nil, nil, nil]

      assert FlightPath.warnings([{:land, :moon}, {nil, :mars}, {:land, :mars}]) ==
               [nil, nil, nil]

      assert FlightPath.warnings([{:land, nil}, {:launch, :mars}]) == [nil, nil]
    end
  end
end
