defmodule FuelCalculator.Planet do
  @moduledoc """
  Planets supported by the fuel calculator and their surface gravity.
  """

  @type t :: :earth | :moon | :mars

  @doc """
  Returns the supported planets, in display order.

  ## Examples

      iex> FuelCalculator.Planet.all()
      [:earth, :moon, :mars]

  """
  @spec all() :: [t()]
  def all, do: [:earth, :moon, :mars]

  @doc """
  Returns the surface gravity of `planet`, in m/s².

  ## Examples

      iex> FuelCalculator.Planet.gravity(:moon)
      1.62

  """
  @spec gravity(t()) :: float()
  def gravity(:earth), do: 9.807
  def gravity(:moon), do: 1.62
  def gravity(:mars), do: 3.711
end
