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
  def gravity(planet), do: gravity_thousandths(planet) / 1000

  @doc """
  Returns the surface gravity of `planet`, in thousandths of m/s², so the fuel
  can be calculated with integers.

  ## Examples

      iex> FuelCalculator.Planet.gravity_thousandths(:moon)
      1620

  """
  @spec gravity_thousandths(t()) :: pos_integer()
  def gravity_thousandths(:earth), do: 9807
  def gravity_thousandths(:moon), do: 1620
  def gravity_thousandths(:mars), do: 3711
end
