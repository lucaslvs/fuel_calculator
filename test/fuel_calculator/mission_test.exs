defmodule FuelCalculator.MissionTest do
  use ExUnit.Case, async: true

  alias FuelCalculator.Fuel
  alias FuelCalculator.Mission

  doctest Mission

  @apollo_11 %{
    "0" => %{"action" => "launch", "planet" => "earth"},
    "1" => %{"action" => "land", "planet" => "moon"},
    "2" => %{"action" => "launch", "planet" => "moon"},
    "3" => %{"action" => "land", "planet" => "earth"}
  }

  defp cast(params), do: Mission.changeset(%Mission{}, params)

  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.fetch!(String.to_existing_atom(key)) |> to_string()
      end)
    end)
  end

  defp steps(count) do
    Map.new(1..count, &{"#{&1 - 1}", %{"action" => "launch", "planet" => "earth"}})
  end

  defp path(changeset) do
    changeset
    |> Ecto.Changeset.apply_changes()
    |> Map.fetch!(:steps)
    |> Enum.map(&{&1.action, &1.planet})
  end

  defp fuel(params) do
    {:ok, mission} = params |> cast() |> Ecto.Changeset.apply_action(:validate)
    Mission.fuel(mission)
  end

  describe "changeset/2 mass" do
    test "is required" do
      assert errors_on(cast(%{"mass" => ""})) == %{mass: ["can't be blank"]}
    end

    test "must be an integer" do
      for mass <- ["abc", "1.5", "1e3"] do
        assert errors_on(cast(%{"mass" => mass})) == %{mass: ["must be a whole number"]}
      end
    end

    test "must be positive" do
      for mass <- ["0", "-1"] do
        assert errors_on(cast(%{"mass" => mass})) == %{mass: ["must be greater than 0"]}
      end
    end

    test "is at most 10^12 kg" do
      assert cast(%{"mass" => "1000000000000"}).valid?

      assert errors_on(cast(%{"mass" => "1000000000001"})) == %{
               mass: ["must be less than or equal to 1000000000000"]
             }
    end
  end

  describe "changeset/2 steps" do
    test "are optional" do
      changeset = cast(%{"mass" => "28801"})

      assert changeset.valid?
      assert path(changeset) == []
    end

    test "must all be valid" do
      steps = %{"0" => %{"action" => "launch", "planet" => "earth"}, "1" => %{"action" => ""}}

      assert errors_on(cast(%{"mass" => "28801", "steps" => steps})) == %{
               steps: [%{}, %{action: ["can't be blank"], planet: ["can't be blank"]}]
             }
    end

    test "can be added as a blank step" do
      changeset =
        cast(%{"mass" => "28801", "steps" => @apollo_11, "steps_sort" => ~w(0 1 2 3 new)})

      refute changeset.valid?
      assert length(path(changeset)) == 5
      assert List.last(path(changeset)) == {nil, nil}
    end

    test "can be removed" do
      changeset =
        cast(%{
          "mass" => "28801",
          "steps" => @apollo_11,
          "steps_sort" => ~w(0 1 2 3),
          "steps_drop" => ["1"]
        })

      assert changeset.valid?
      assert path(changeset) == [launch: :earth, launch: :moon, land: :earth]
    end

    test "must be given as maps" do
      for steps <- [%{"0" => ["x"]}, %{"0" => []}, [["x"]]] do
        assert errors_on(cast(%{"mass" => "28801", "steps" => steps})) == %{
                 steps: ["is invalid"]
               }
      end
    end

    test "ignore an order or removal that is not a list" do
      changeset =
        cast(%{
          "mass" => "28801",
          "steps" => @apollo_11,
          "steps_sort" => "x",
          "steps_drop" => %{"0" => "x"}
        })

      assert changeset.valid?
      assert path(changeset) == [launch: :earth, land: :moon, launch: :moon, land: :earth]
    end

    test "can be reordered" do
      changeset =
        cast(%{"mass" => "28801", "steps" => @apollo_11, "steps_sort" => ~w(3 2 1 0)})

      assert path(changeset) == [land: :earth, launch: :moon, land: :moon, launch: :earth]
    end
  end

  describe "changeset/2 step limit" do
    test "allows up to 15 steps" do
      changeset = cast(%{"mass" => "28801", "steps" => steps(15)})

      assert changeset.valid?
      assert length(path(changeset)) == 15
    end

    test "rejects more than 15 steps" do
      for params <- [
            %{"mass" => "28801", "steps" => steps(16)},
            %{"mass" => "28801", "steps" => Map.values(steps(16))},
            %{"mass" => "28801", "steps_sort" => List.duplicate("new", 16)},
            %{"mass" => "28801", "steps_drop" => List.duplicate("0", 16)},
            %{mass: 28_801, steps: Map.values(steps(16))}
          ] do
        assert errors_on(cast(params)) == %{steps: ["should have at most 15 item(s)"]},
               "#{inspect(params)} was accepted"
      end
    end

    test "counts the steps out of the order after the ordered ones" do
      changeset =
        cast(%{
          "mass" => "28801",
          "steps_sort" => List.duplicate("new", 10),
          "steps" => Map.new(steps(10), fn {key, step} -> {"x" <> key, step} end)
        })

      assert length(path(changeset)) == 20

      assert {"should have at most %{count} item(s)", [{:count, 15} | _]} =
               changeset.errors[:steps]
    end

    test "rejects oversized params without casting their steps" do
      changeset = cast(%{"mass" => "28801", "steps_sort" => List.duplicate("new", 100_000)})

      assert errors_on(changeset) == %{steps: ["should have at most 15 item(s)"]}
      assert Ecto.Changeset.get_change(changeset, :steps) == nil
    end

    test "is exposed" do
      assert Mission.max_steps() == 15
    end
  end

  describe "calculate/1" do
    test "returns the fuel of a valid mission" do
      assert {:ok, %{total: 51_898, details: details}} =
               Mission.calculate(cast(%{"mass" => "28801", "steps" => @apollo_11}))

      assert Enum.map(details, & &1.fuel) == [32_988, 2462, 3001, 13_447]
    end

    test "returns the changeset of an invalid mission with its errors" do
      assert {:error, changeset} = Mission.calculate(cast(%{"mass" => "0"}))
      assert changeset.action == :validate
      assert errors_on(changeset) == %{mass: ["must be greater than 0"]}
    end
  end

  describe "missing/1" do
    test "is empty for a complete mission" do
      assert Mission.missing(cast(%{"mass" => "28801", "steps" => @apollo_11})) == []
    end

    test "is empty for a mass and an empty path" do
      assert Mission.missing(cast(%{"mass" => "28801"})) == []
    end

    test "lists a blank mass" do
      for mass <- [nil, "", " "] do
        assert Mission.missing(cast(%{"mass" => mass, "steps" => @apollo_11})) ==
                 [{:mass, :blank}],
               "mass #{inspect(mass)}"
      end
    end

    test "lists an invalid mass" do
      for mass <- ["0", "-1", "abc", "1.5", "1000000000001"] do
        assert Mission.missing(cast(%{"mass" => mass, "steps" => @apollo_11})) ==
                 [{:mass, :invalid}],
               "mass #{inspect(mass)}"
      end
    end

    test "lists the fields each incomplete step lacks, after the mass" do
      steps = %{
        "0" => %{"action" => "launch", "planet" => "earth"},
        "1" => %{},
        "2" => %{"action" => "land"},
        "3" => %{"planet" => "moon"}
      }

      assert Mission.missing(cast(%{"steps" => steps})) == [
               {:mass, :blank},
               {:step, 1, [:action, :planet]},
               {:step, 2, [:planet]},
               {:step, 3, [:action]}
             ]
    end

    test "lists an unknown action or planet as lacking" do
      steps = %{"0" => %{"action" => "orbit", "planet" => "pluto"}}

      assert Mission.missing(cast(%{"mass" => "28801", "steps" => steps})) ==
               [{:step, 0, [:action, :planet]}]
    end
  end

  describe "fuel/1" do
    test "calculates the Apollo 11 mission" do
      assert %{total: 51_898, details: details} =
               fuel(%{"mass" => "28801", "steps" => @apollo_11})

      assert details ==
               Fuel.explain(28_801, launch: :earth, land: :moon, launch: :moon, land: :earth)
    end

    test "calculates the Mars mission" do
      steps = %{
        "0" => %{"action" => "launch", "planet" => "earth"},
        "1" => %{"action" => "land", "planet" => "mars"},
        "2" => %{"action" => "launch", "planet" => "mars"},
        "3" => %{"action" => "land", "planet" => "earth"}
      }

      assert %{total: 33_388} = fuel(%{"mass" => "14606", "steps" => steps})
    end

    test "calculates the passenger ship mission" do
      steps = %{
        "0" => %{"action" => "launch", "planet" => "earth"},
        "1" => %{"action" => "land", "planet" => "moon"},
        "2" => %{"action" => "launch", "planet" => "moon"},
        "3" => %{"action" => "land", "planet" => "mars"},
        "4" => %{"action" => "launch", "planet" => "mars"},
        "5" => %{"action" => "land", "planet" => "earth"}
      }

      assert %{total: 212_161} = fuel(%{"mass" => "75432", "steps" => steps})
    end

    test "requires no fuel for an empty path" do
      assert fuel(%{"mass" => "28801"}) == %{total: 0, details: []}
    end
  end
end
