defmodule FuelCalculator.FlightPathTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias FuelCalculator.FlightPath
  alias FuelCalculator.Planet

  doctest FlightPath

  describe "warnings/1" do
    test "finds nothing wrong in the missions of the challenge" do
      for path <- [
            [launch: :earth, land: :moon, launch: :moon, land: :earth],
            [launch: :earth, land: :mars, launch: :mars, land: :earth],
            [launch: :earth, land: :moon, launch: :moon, land: :mars, launch: :mars, land: :earth]
          ] do
        assert FlightPath.warnings(path) == List.duplicate(nil, length(path))
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

  describe "warnings/1 properties" do
    property "finds nothing wrong when every launch is from the planet of the last landing" do
      check all path <- flyable_path() do
        assert FlightPath.warnings(path) == List.duplicate(nil, length(path))
      end
    end

    property "warns about the same action twice in a row" do
      check all path <- flyable_path(2),
                index <- integer(1..(length(path) - 1)) do
        {action, _planet} = Enum.at(path, index - 1)
        path = List.update_at(path, index, fn {_action, planet} -> {action, planet} end)

        assert Enum.at(FlightPath.warnings(path), index) ==
                 if(action == :land, do: :land_twice, else: :launch_twice)
      end
    end
  end

  describe "fixes/1" do
    test "launches from the planet of the last landing instead" do
      assert FlightPath.fixes(launch: :earth, land: :moon, launch: :mars) ==
               [nil, nil, {:launch, :moon}]
    end

    test "lands on the planet instead of launching again" do
      assert FlightPath.fixes(launch: :earth, launch: :moon) == [nil, {:land, :moon}]
    end

    test "launches from the planet of the last landing instead of landing again" do
      assert FlightPath.fixes(launch: :earth, land: :moon, land: :mars) ==
               [nil, nil, {:launch, :moon}]
    end

    test "has nothing to fix in a path without warnings or with incomplete steps" do
      assert FlightPath.fixes(launch: :earth, land: :moon, launch: :moon) == [nil, nil, nil]
      assert FlightPath.fixes([{:launch, :earth}, {nil, :moon}, {:land, nil}]) == [nil, nil, nil]
      assert FlightPath.fixes([]) == []
    end
  end

  describe "fixes/1 properties" do
    property "a fix makes its step follow the previous one" do
      check all path <- list_of(step(), min_length: 2, max_length: 8) do
        for {{action, planet}, index} <- Enum.with_index(FlightPath.fixes(path)) do
          fixed = List.replace_at(path, index, {action, planet})

          assert Enum.at(FlightPath.warnings(fixed), index) == nil
        end
      end
    end

    property "there is a fix for every warning and only for them" do
      check all path <- list_of(step(), max_length: 8) do
        assert Enum.map(FlightPath.fixes(path), &is_nil/1) ==
                 Enum.map(FlightPath.warnings(path), &is_nil/1)
      end
    end
  end

  defp step, do: tuple({member_of([:launch, :land]), member_of(Planet.all())})

  # Launches from each planet and lands on the next one; may stop after a launch
  defp flyable_path(min_planets \\ 1) do
    gen all planets <- list_of(member_of(Planet.all()), min_length: min_planets, max_length: 8),
            stop_after_launch? <- boolean() do
      path =
        planets
        |> Enum.chunk_every(2, 1, :discard)
        |> Enum.flat_map(fn [from, to] -> [launch: from, land: to] end)

      if stop_after_launch?, do: path ++ [launch: List.last(planets)], else: path
    end
  end
end
