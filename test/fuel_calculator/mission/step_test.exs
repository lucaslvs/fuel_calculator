defmodule FuelCalculator.Mission.StepTest do
  use ExUnit.Case, async: true

  alias FuelCalculator.Mission.Step
  alias FuelCalculator.Planet

  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, _opts} -> message end)
  end

  describe "changeset/2" do
    test "casts every action on every planet" do
      for action <- [:launch, :land], planet <- Planet.all() do
        params = %{"action" => Atom.to_string(action), "planet" => Atom.to_string(planet)}
        changeset = Step.changeset(%Step{}, params)

        assert changeset.valid?
        assert Ecto.Changeset.apply_changes(changeset) == %Step{action: action, planet: planet}
      end
    end

    test "requires an action and a planet" do
      changeset = Step.changeset(%Step{}, %{"action" => "", "planet" => ""})

      assert errors_on(changeset) == %{action: ["can't be blank"], planet: ["can't be blank"]}
    end

    test "rejects an unknown action or planet" do
      changeset = Step.changeset(%Step{}, %{"action" => "fly", "planet" => "jupiter"})

      assert errors_on(changeset) == %{action: ["is invalid"], planet: ["is invalid"]}
    end
  end
end
