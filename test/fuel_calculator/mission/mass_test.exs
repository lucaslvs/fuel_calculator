defmodule FuelCalculator.Mission.MassTest do
  use ExUnit.Case, async: true

  alias FuelCalculator.Mission.Mass

  test "casts an integer, from digits that may be grouped with commas" do
    for mass <- ["28801", "28,801", "2,8801", 28_801] do
      assert Mass.cast(mass) == {:ok, 28_801}
    end
  end

  test "casts nothing else" do
    for mass <- ["28,801.5", "28 801", "abc", 28_801.5] do
      assert Mass.cast(mass) == :error
    end
  end

  test "is an integer when loaded and dumped" do
    assert Mass.type() == :integer
    assert Mass.load(28_801) == {:ok, 28_801}
    assert Mass.dump(28_801) == {:ok, 28_801}
  end
end
