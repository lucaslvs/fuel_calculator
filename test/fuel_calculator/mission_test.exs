defmodule FuelCalculator.MissionTest do
  use ExUnit.Case, async: true

  alias FuelCalculator.Mission
  alias FuelCalculator.Mission.Step

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
        assert errors_on(cast(%{"mass" => mass})) == %{mass: ["is invalid"]}
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

    test "already in the mission must be valid when the params leave them untouched" do
      changeset = Mission.changeset(%Mission{steps: [%Step{}]}, %{"mass" => "28801"})

      assert errors_on(changeset) == %{steps: ["is invalid"]}
    end

    test "already in the mission are kept when the params leave them untouched" do
      mission = %Mission{steps: [%Step{action: :land, planet: :earth}]}

      assert Mission.calculate(Mission.changeset(mission, %{"mass" => "28801"})) ==
               {:ok, %{total: 13_447, steps: [13_447]}}
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

    test "can be reordered" do
      changeset =
        cast(%{"mass" => "28801", "steps" => @apollo_11, "steps_sort" => ~w(3 2 1 0)})

      assert path(changeset) == [land: :earth, launch: :moon, land: :moon, launch: :earth]
    end
  end

  describe "calculate/1" do
    test "returns the fuel of a valid mission" do
      assert Mission.calculate(cast(%{"mass" => "28801", "steps" => @apollo_11})) ==
               {:ok, %{total: 51_898, steps: [32_988, 2462, 3001, 13_447]}}
    end

    test "returns the changeset of an invalid mission with its errors" do
      assert {:error, changeset} = Mission.calculate(cast(%{"mass" => "0"}))
      assert changeset.action == :validate
      assert errors_on(changeset) == %{mass: ["must be greater than 0"]}
    end
  end

  describe "fuel/1" do
    test "calculates the Apollo 11 mission" do
      assert fuel(%{"mass" => "28801", "steps" => @apollo_11}) ==
               %{total: 51_898, steps: [32_988, 2462, 3001, 13_447]}
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
      assert fuel(%{"mass" => "28801"}) == %{total: 0, steps: []}
    end
  end
end
