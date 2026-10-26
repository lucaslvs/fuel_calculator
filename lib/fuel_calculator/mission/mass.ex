defmodule FuelCalculator.Mission.Mass do
  @moduledoc """
  The type of a mission's mass: an integer, cast from digits that may be grouped
  with commas, as in "28,801".

  The changeset keeps the text as it was given, so a form shows an invalid mass
  the way it was typed.
  """

  use Ecto.Type

  @impl true
  def type, do: :integer

  @impl true
  def cast(mass) when is_binary(mass), do: Ecto.Type.cast(:integer, String.replace(mass, ",", ""))
  def cast(mass), do: Ecto.Type.cast(:integer, mass)

  @impl true
  def load(mass), do: Ecto.Type.load(:integer, mass)

  @impl true
  def dump(mass), do: Ecto.Type.dump(:integer, mass)
end
