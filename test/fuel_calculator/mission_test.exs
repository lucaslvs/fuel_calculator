defmodule FuelCalculator.MissionTest do
  use ExUnit.Case, async: true

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

  defp path(changeset) do
    changeset
    |> Ecto.Changeset.apply_changes()
    |> Map.fetch!(:steps)
    |> Enum.map(&{&1.action, &1.planet})
  end

  defp total_fuel(params) do
    {:ok, mission} = params |> cast() |> Ecto.Changeset.apply_action(:validate)
    Mission.total_fuel(mission)
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

  describe "total_fuel/1" do
    test "calculates the Apollo 11 mission" do
      assert total_fuel(%{"mass" => "28801", "steps" => @apollo_11}) == 51_898
    end

    test "calculates the Mars mission" do
      steps = %{
        "0" => %{"action" => "launch", "planet" => "earth"},
        "1" => %{"action" => "land", "planet" => "mars"},
        "2" => %{"action" => "launch", "planet" => "mars"},
        "3" => %{"action" => "land", "planet" => "earth"}
      }

      assert total_fuel(%{"mass" => "14606", "steps" => steps}) == 33_388
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

      assert total_fuel(%{"mass" => "75432", "steps" => steps}) == 212_161
    end

    test "requires no fuel for an empty path" do
      assert total_fuel(%{"mass" => "28801"}) == 0
    end
  end
end
