defmodule FuelCalculator.Mission.Step do
  @moduledoc """
  A step of a flight path: launching from or landing on a planet.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias FuelCalculator.Fuel
  alias FuelCalculator.Planet

  @type t :: %__MODULE__{action: Fuel.action() | nil, planet: Planet.t() | nil}

  @primary_key false
  embedded_schema do
    field :action, Ecto.Enum, values: Fuel.actions()
    field :planet, Ecto.Enum, values: Planet.all()
  end

  @doc """
  Casts and validates the action and planet of a step.
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(step, attrs) do
    step
    |> cast(attrs, [:action, :planet])
    |> validate_required([:action, :planet])
  end
end
