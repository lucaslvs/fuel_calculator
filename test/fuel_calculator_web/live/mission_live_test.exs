defmodule FuelCalculatorWeb.MissionLiveTest do
  use FuelCalculatorWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "GET / renders the mission form without parameters", %{conn: conn} do
    document = conn |> get(~p"/") |> html_response(200) |> LazyHTML.from_document()

    assert document |> LazyHTML.query("#mission-form") |> Enum.count() == 1
  end

  describe "mount" do
    test "starts with a blank mass, one blank step and no total", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      refute has_element?(view, "#mission_mass[value]:not([value=''])")
      assert has_element?(view, "#step-0")
      refute has_element?(view, "#step-1")
      refute has_element?(view, "#step-0 option[selected]")
      refute has_element?(view, "#empty-path")
      assert has_element?(view, "#total-fuel", "—")
      refute has_element?(view, ".input-error, .select-error")
    end

    test "offers every action and planet", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      assert option_values(view, "#mission_steps_0_action") == ["", "launch", "land"]
      assert option_values(view, "#mission_steps_0_planet") == ["", "earth", "moon", "mars"]
    end
  end

  describe "total fuel" do
    for {name, mass, path, total} <- [
          {"Apollo 11", 28_801, [launch: :earth, land: :moon, launch: :moon, land: :earth],
           "51,898 kg"},
          {"Mars", 14_606, [launch: :earth, land: :mars, launch: :mars, land: :earth],
           "33,388 kg"},
          {"passenger ship", 75_432,
           [
             launch: :earth,
             land: :moon,
             launch: :moon,
             land: :mars,
             launch: :mars,
             land: :earth
           ], "212,161 kg"}
        ] do
      test "is calculated for the #{name} mission", %{conn: conn} do
        {:ok, view, _html} = live(conn, ~p"/")

        change(view, mission(unquote(mass), unquote(path)))

        assert has_element?(view, "#total-fuel", unquote(total))
      end
    end

    test "is formatted with thousands separators", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      change(view, mission(1_000_000_000_000, launch: :earth, land: :earth))

      assert has_element?(view, "#total-fuel", "1,513,973,496,138 kg")
      assert has_element?(view, "#step-fuel-0", "1,035,490,598,312 kg")
    end

    test "is cleared when the mass becomes invalid", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      for mass <- ["0", "-1", "abc"] do
        change(view, mission(28_801, land: :earth))
        assert has_element?(view, "#total-fuel", "13,447 kg")

        change(view, mission(mass, land: :earth))

        assert has_element?(view, "#mission_mass.input-error")
        assert has_element?(view, "#total-fuel", "—")
      end
    end

    test "is cleared when a step becomes incomplete", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      change(view, mission(28_801, land: :earth))
      assert has_element?(view, "#total-fuel", "13,447 kg")

      change(view, %{
        "mass" => "28801",
        "steps_sort" => ["0"],
        "steps" => %{"0" => %{"action" => "land", "planet" => ""}}
      })

      assert has_element?(view, "#mission_steps_0_planet.select-error")
      assert has_element?(view, "#total-fuel", "—")
    end
  end

  describe "step fuel" do
    test "is shown for each step of a valid mission", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      change(view, mission(28_801, launch: :earth, land: :moon, launch: :moon, land: :earth))

      for {fuel, index} <- Enum.with_index(["32,988 kg", "2,462 kg", "3,001 kg", "13,447 kg"]) do
        assert has_element?(view, "#step-#{index} #step-fuel-#{index}", fuel)
      end
    end

    test "is hidden while the mission is invalid", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      change(view, mission(28_801, land: :moon, land: :earth))
      assert has_element?(view, "#step-fuel-1")

      change(view, mission("", land: :moon, land: :earth))

      refute has_element?(view, "[id^=step-fuel-]")
    end
  end

  describe "validation" do
    test "hides errors of steps the user has not touched", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      change(view, %{
        "mass" => "28801",
        "steps_sort" => ["0"],
        "steps" => %{
          "0" => %{
            "_unused_action" => "",
            "action" => "",
            "_unused_planet" => "",
            "planet" => ""
          }
        }
      })

      refute has_element?(view, ".input-error, .select-error")
    end

    test "shows every error on submit", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      view
      |> element("#mission-form")
      |> render_submit(%{"mission" => %{"mass" => "", "steps_sort" => ["0"]}})

      assert has_element?(view, "#mission_mass.input-error")
      assert has_element?(view, "#mission_steps_0_action.select-error")
      assert has_element?(view, "#mission_steps_0_planet.select-error")
    end
  end

  # The add and remove buttons trigger a form change through JS, which LiveViewTest
  # does not run, so these tests send the steps_sort and steps_drop values the
  # buttons add to the form.
  describe "flight path" do
    test "adds a blank step and keeps the entered values", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      change(view, %{mission(28_801, land: :earth) | "steps_sort" => ["0", "new"]})

      assert has_element?(view, "#mission_mass[value='28801']")
      assert has_element?(view, "#mission_steps_0_action option[value='land'][selected]")
      assert has_element?(view, "#mission_steps_0_planet option[value='earth'][selected]")
      assert has_element?(view, "#step-1")
      refute has_element?(view, "#step-1 option[selected]")
    end

    test "removes a step", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      change(view, mission(28_801, land: :moon, land: :earth))
      change(view, Map.put(mission(28_801, land: :moon, land: :earth), "steps_drop", ["0"]))

      assert has_element?(view, "#step-0")
      refute has_element?(view, "#step-1")
      assert has_element?(view, "#total-fuel", "13,447 kg")
    end

    test "removing the only step leaves an empty path that needs no fuel", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      change(view, %{"mass" => "28801", "steps_sort" => ["0"], "steps_drop" => ["0"]})

      refute has_element?(view, "#step-0")
      assert has_element?(view, "#empty-path")
      assert has_element?(view, "#total-fuel", "0 kg")
    end

    test "hides the empty path message once a step is added", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      change(view, %{"mass" => "28801", "steps_sort" => ["0"], "steps_drop" => ["0"]})
      change(view, %{"mass" => "28801", "steps_sort" => ["new"]})

      assert has_element?(view, "#step-0")
      refute has_element?(view, "#empty-path")
    end

    test "numbers the steps", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      change(view, mission(28_801, launch: :earth, land: :moon))

      refute has_element?(view, "#empty-path")
      assert has_element?(view, "#step-0 [data-role=step-number]", "1")
      assert has_element?(view, "#step-1 [data-role=step-number]", "2")
    end
  end

  defp change(view, params) do
    view
    |> element("#mission-form")
    |> render_change(%{"mission" => params})
  end

  defp option_values(view, select) do
    view
    |> render()
    |> LazyHTML.from_fragment()
    |> LazyHTML.query("#{select} option")
    |> LazyHTML.attribute("value")
  end

  defp mission(mass, path) do
    steps =
      path
      |> Enum.with_index()
      |> Map.new(fn {{action, planet}, index} ->
        {"#{index}", %{"action" => "#{action}", "planet" => "#{planet}"}}
      end)

    %{
      "mass" => "#{mass}",
      "steps_sort" => Enum.map(0..(length(path) - 1)//1, &"#{&1}"),
      "steps" => steps
    }
  end
end
