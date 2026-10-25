defmodule FuelCalculatorWeb.MissionLiveTest do
  use FuelCalculatorWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias FuelCalculator.Fuel

  @apollo [launch: :earth, land: :moon, launch: :moon, land: :earth]

  # The missions of the challenge, also offered as examples (by id)
  @missions [
    {"apollo-11", 28_801, @apollo, "51,898 kg"},
    {"mars", 14_606, [launch: :earth, land: :mars, launch: :mars, land: :earth], "33,388 kg"},
    {"passenger-ship", 75_432,
     [launch: :earth, land: :moon, launch: :moon, land: :mars, launch: :mars, land: :earth],
     "212,161 kg"}
  ]

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
      refute has_element?(view, "#step-0 option[selected], #step-0 input[checked]")
      refute has_element?(view, "#empty-path")
      assert has_element?(view, "#total-fuel", exactly("Not calculated yet"))
      refute has_element?(view, ".input-error, .select-error, [aria-invalid]")
    end

    test "titles the page with a single heading", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      headings = query(view, "h1")

      assert has_element?(view, "h1", "Interplanetary fuel calculator")
      assert Enum.count(headings) == 1
    end

    test "names the theme buttons", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      for {theme, name} <- [system: "System theme", light: "Light theme", dark: "Dark theme"] do
        assert has_element?(view, "button[data-phx-theme=#{theme}][aria-label='#{name}']")
      end
    end

    test "limits the mass input to the largest mass", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(view, "#mission_mass[min='1'][max='1000000000000']")
    end

    test "shows the mass unit and an example mass", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(view, ".input #mission_mass ~ .label", "kg")
      assert has_element?(view, "#mission_mass[placeholder='e.g. 28801'][inputmode=numeric]")
    end

    test "puts the mass unit in the input's name in parentheses", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(view, "label[for=mission_mass] .sr-only", exactly("(kg)"))
      assert has_element?(view, "#mission_mass ~ .label[aria-hidden=true]", "kg")
    end

    test "waits for a pause in typing before recalculating", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(view, "#mission_mass[phx-debounce='300']")
    end

    test "offers every action and planet", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      assert radio_values(view, "#mission_steps_0_action") == ["launch", "land"]
      assert option_values(view, "#mission_steps_0_planet") == ["", "earth", "moon", "mars"]
    end
  end

  describe "mass hint" do
    for {mass, hint} <- [{28_801, "28,801 kg"}, {1_000_000_000_000, "1,000,000,000,000 kg"}] do
      test "formats the valid mass #{mass}", %{conn: conn} do
        {:ok, view, _html} = live(conn, ~p"/")

        change(view, mission(unquote(mass), land: :earth))

        assert has_element?(view, "#mass-hint", unquote(hint))
        assert has_element?(view, "#mission_mass[aria-describedby=mass-hint]")
      end
    end

    test "is shown while the flight path is still incomplete", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      change(view, %{"mass" => "28801", "steps_sort" => ["0"], "steps" => %{"0" => %{}}})

      assert has_element?(view, "#total-fuel", exactly("Not calculated yet"))
      assert has_element?(view, "#mass-hint", "28,801 kg")
    end

    test "is hidden without a valid mass", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      refute has_element?(view, "#mass-hint")

      for mass <- ["", "0", "-1", "abc", "1000000000001"] do
        change(view, mission(28_801, land: :earth))
        change(view, mission(mass, land: :earth))

        refute has_element?(view, "#mass-hint"), "mass #{inspect(mass)}"

        refute has_element?(view, "#mission_mass[aria-describedby~=mass-hint]"),
               "mass #{inspect(mass)}"
      end
    end
  end

  describe "total fuel" do
    for {name, mass, path, total} <- @missions do
      test "is calculated for the #{name} mission", %{conn: conn} do
        {:ok, view, _html} = live(conn, ~p"/")

        change(view, mission(unquote(mass), unquote(path)))

        assert has_element?(view, "#total-fuel", exactly(unquote(total)))
      end
    end

    test "is formatted with thousands separators", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      change(view, mission(1_000_000_000_000, launch: :earth, land: :earth))

      assert has_element?(view, "#total-fuel", exactly("1,513,973,496,138 kg"))
      assert has_element?(view, "#step-details-0 summary", "How 1,035,490,598,312 kg is")
    end

    test "is announced to screen readers when it changes", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(view, "#total-fuel[aria-live=polite][aria-atomic=true]")
      assert has_element?(view, "#total-fuel", exactly("Not calculated yet"))

      change(view, mission(28_801, land: :earth))

      assert has_element?(view, "#total-fuel", exactly("13,447 kg"))
    end

    test "is cleared when the mass becomes invalid", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      for mass <- ["0", "-1", "abc", "1000000000001"] do
        change(view, mission(28_801, land: :earth))
        assert has_element?(view, "#total-fuel", exactly("13,447 kg"))

        change(view, mission(mass, land: :earth))

        assert has_element?(view, ".input-error #mission_mass"), "mass #{inspect(mass)}"

        assert has_element?(view, "#total-fuel", exactly("Not calculated yet")),
               "mass #{inspect(mass)}"
      end
    end

    test "is cleared when a step becomes incomplete", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      change(view, mission(28_801, land: :earth))
      assert has_element?(view, "#total-fuel", exactly("13,447 kg"))

      change(view, mission(28_801, land: nil))

      assert has_element?(view, "#mission_steps_0_planet.select-error")
      assert has_element?(view, "#total-fuel", exactly("Not calculated yet"))
    end

    test "is broken down by step", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      load_example(view, "apollo-11")

      steps = [
        {"1 · Launch from Earth", "32,988 kg", 32_988},
        {"2 · Land on the Moon", "2,462 kg", 2_462},
        {"3 · Launch from the Moon", "3,001 kg", 3_001},
        {"4 · Land on Earth", "13,447 kg", 13_447}
      ]

      for {{label, fuel, value}, index} <- Enum.with_index(steps, 1) do
        item = "#fuel-by-step li:nth-child(#{index})"

        assert has_element?(view, "#{item} [data-role=label]", exactly(label))
        assert has_element?(view, "#{item} [data-role=fuel]", exactly(fuel))
        # Each bar is relative to the step that needs the most fuel
        assert has_element?(view, "#{item} progress[value='#{value}'][max='32988']")
      end

      refute has_element?(view, "#fuel-by-step li:nth-child(5)")
    end

    test "is not broken down while the mission is invalid", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      refute has_element?(view, "#fuel-by-step")

      load_example(view, "apollo-11")
      assert has_element?(view, "#fuel-by-step")

      change(view, mission("", launch: :earth, land: :moon))
      refute has_element?(view, "#fuel-by-step")
    end

    test "tells how many steps the summary covers", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      change(view, mission(28_801, land: :earth))
      assert has_element?(view, "#fuel-summary-steps", exactly("1 step"))

      load_example(view, "apollo-11")
      assert has_element?(view, "#fuel-summary-steps", exactly("4 steps"))
    end
  end

  describe "pending total" do
    test "tells the first thing the mission is missing and how many more", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(view, "#fuel-pending p", exactly("Enter the spacecraft mass · 1 more"))
      assert has_element?(view, "#fuel-pending-go", "Go to the mass")
      assert focus_target(view, "#fuel-pending-go") == "#mission_mass"
    end

    test "asks for a valid mass", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      change(view, mission(0, land: :earth))

      assert has_element?(view, "#fuel-pending p", exactly("Enter a valid spacecraft mass"))
      assert focus_target(view, "#fuel-pending-go") == "#mission_mass"
    end

    test "asks for what an incomplete step lacks", %{conn: conn} do
      cases = [
        {[launch: :earth, land: nil], "Choose a planet for step 2", "Go to step 2",
         "#mission_steps_1_planet"},
        {[{nil, :moon}], "Choose an action for step 1", "Go to step 1",
         "#mission_steps_0_action_launch"},
        {[launch: :earth, land: :moon, launch: :moon, land: :earth] ++ [{nil, nil}],
         "Choose an action and a planet for step 5", "Go to step 5",
         "#mission_steps_4_action_launch"}
      ]

      # A new view each time: a change keeps the steps already in the page
      for {path, sentence, go, target} <- cases do
        {:ok, view, _html} = live(conn, ~p"/")
        change(view, mission(28_801, path))

        assert has_element?(view, "#fuel-pending p", exactly(sentence))
        assert has_element?(view, "#fuel-pending-go", exactly(go))
        assert focus_target(view, "#fuel-pending-go") == target
      end
    end

    test "is replaced by the total once the mission is complete", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      change(view, mission(28_801, land: :earth))

      refute has_element?(view, "#fuel-pending")
      assert has_element?(view, "#fuel-summary .stat-desc", "Includes the fuel to carry the fuel")
    end

    test "tells what is missing in the bar below lg", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(view, "#fuel-summary-steps", exactly("Spacecraft mass · +1"))

      change(view, mission(28_801, launch: :earth, land: nil))
      assert has_element?(view, "#fuel-summary-steps", exactly("Step 2: planet"))

      change(view, mission(28_801, [launch: :earth, land: :moon, launch: :moon] ++ [{nil, nil}]))
      assert has_element?(view, "#fuel-summary-steps", exactly("Step 4: action and planet"))
    end
  end

  describe "examples" do
    for {id, mass, path, total} <- @missions do
      test "loads the #{id} mission", %{conn: conn} do
        {:ok, view, _html} = live(conn, ~p"/")

        load_example(view, unquote(id))

        assert has_element?(view, "#mission_mass[value='#{unquote(mass)}']")

        for {{action, planet}, index} <- Enum.with_index(unquote(path)) do
          assert has_element?(view, "#step-#{index} input[value='#{action}'][checked]")
          assert has_element?(view, "#step-#{index} option[value='#{planet}'][selected]")
        end

        refute has_element?(view, "#step-#{length(unquote(path))}")
        assert has_element?(view, "#total-fuel", exactly(unquote(total)))
      end
    end

    test "replaces a longer flight path without showing errors", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      load_example(view, "passenger-ship")
      assert has_element?(view, "#step-5")

      load_example(view, "mars")

      assert has_element?(view, "#step-3")
      refute has_element?(view, "#step-4")
      refute has_element?(view, ".input-error, .select-error, [aria-invalid]")
      assert has_element?(view, "#total-fuel", exactly("33,388 kg"))
    end

    test "shows each example's name, route, mass and steps", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      for {id, name} <- [
            {"apollo-11", "Apollo 11"},
            {"mars", "Mars mission"},
            {"passenger-ship", "Passenger ship"}
          ] do
        assert has_element?(view, "#example-#{id}", name)
      end

      assert texts(view, "#example-apollo-11 [data-role=planet]") == ~w(Earth Moon Earth)
      assert texts(view, "#example-mars [data-role=planet]") == ~w(Earth Mars Earth)

      assert texts(view, "#example-passenger-ship [data-role=planet]") ==
               ~w(Earth Moon Mars Earth)

      assert has_element?(view, "#example-apollo-11 [data-role=size]", "28,801 kg · 4 steps")
      assert has_element?(view, "#example-mars [data-role=size]", "14,606 kg · 4 steps")
      assert has_element?(view, "#example-passenger-ship [data-role=size]", "75,432 kg · 6 steps")
    end

    test "marks no example before one is loaded", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      # The cards don't toggle, so they have no pressed state
      refute has_element?(view, "[id^=example-][aria-current], [id^=example-][aria-pressed]")
      refute has_element?(view, "#loaded-example")
    end

    test "marks the loaded example and only it", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      load_example(view, "passenger-ship")
      assert current_examples(view) == ["example-passenger-ship"]
      refute has_element?(view, "[id^=example-][aria-current]:not([aria-current=true])")

      load_example(view, "mars")
      assert current_examples(view) == ["example-mars"]
    end

    test "describes the loaded example below the cards", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      load_example(view, "passenger-ship")

      assert texts(view, "#loaded-example [data-role=planet]") == ~w(Earth Moon Mars Earth)
      assert has_element?(view, "#loaded-example", "75,432 kg · 6 steps")
    end

    test "unmarks the example while the mission differs from it", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      load_example(view, "apollo-11")

      change(view, mission(28_802, @apollo))
      assert current_examples(view) == []
      refute has_element?(view, "#loaded-example")

      change(view, mission(28_801, @apollo))
      assert current_examples(view) == ["example-apollo-11"]

      change(view, mission(28_801, List.replace_at(@apollo, 1, {:land, :mars})))
      assert current_examples(view) == []

      change(view, Map.put(mission(28_801, @apollo), "steps_drop", ["3"]))
      refute has_element?(view, "#step-3")
      assert current_examples(view) == []
    end

    test "marks an example typed in by hand", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      change(view, mission(14_606, launch: :earth, land: :mars, launch: :mars, land: :earth))

      assert current_examples(view) == ["example-mars"]
    end

    test "ignores an unknown example", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      change(view, mission(28_801, land: :earth))
      render_hook(view, "load_example", %{"id" => "nope"})

      assert has_element?(view, "#mission_mass[value='28801']")
      refute has_element?(view, "#step-1")
      assert has_element?(view, "#total-fuel", exactly("13,447 kg"))
    end
  end

  describe "step fuel" do
    test "is in the summary of each step's details for a valid mission", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      change(view, mission(28_801, @apollo))

      for {fuel, index} <- Enum.with_index(["32,988 kg", "2,462 kg", "3,001 kg", "13,447 kg"]) do
        assert has_element?(
                 view,
                 "#step-#{index} #step-details-#{index} summary",
                 "How #{fuel} is"
               )
      end
    end

    test "is not shown next to the step's title", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      change(view, mission(28_801, @apollo))

      refute has_element?(view, "#step-0 [data-role=step-title]", "kg")
      refute has_element?(view, "[id^=step-fuel-]")
    end

    test "is left out while the mission is invalid", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      change(view, mission(28_801, land: :moon, land: :earth))
      refute has_element?(view, "#step-details-1 summary", "How the fuel is calculated")

      change(view, mission("", land: :moon, land: :earth))
      assert has_element?(view, "#step-details-1 summary", "How the fuel is calculated")

      change(view, mission(28_801, land: :moon, land: nil))
      assert has_element?(view, "#step-details-0 summary", "How the fuel is calculated")
    end
  end

  describe "fuel explanation" do
    test "says there are no later steps only on the last step", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      # So light that no step needs fuel, so every step carries just the spacecraft
      change(view, mission(1, launch: :earth, land: :moon))

      assert has_element?(
               view,
               "#step-details-0 [data-role=mass]",
               "1 kg spacecraft + 0 kg of fuel for the later steps = 1 kg"
             )

      assert has_element?(view, "#step-details-1 [data-role=mass]", "1 kg (no later steps)")
    end

    test "shows the mass, the formula and the iterations of each step", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      change(view, mission(28_801, @apollo))

      assert has_element?(view, "#step-3 #step-details-3 summary", "How 13,447 kg is calculated")
      assert has_element?(view, "#step-details-3 [data-role=mass]", "28,801 kg (no later steps)")

      assert has_element?(
               view,
               "#step-details-3 [data-role=formula]",
               "Land on Earth: mass × 9.807 × 0.033 − 42"
             )

      assert has_element?(
               view,
               "#step-details-3 [data-role=iterations]",
               "9,278 + 2,960 + 915 + 254 + 40 = 13,447 kg"
             )

      assert has_element?(
               view,
               "#step-details-0 [data-role=mass]",
               "28,801 kg spacecraft + 18,910 kg of fuel for the later steps = 47,711 kg"
             )

      assert has_element?(
               view,
               "#step-details-0 [data-role=formula]",
               "Launch from Earth: mass × 9.807 × 0.042 − 33"
             )

      assert has_element?(
               view,
               "#step-details-1 [data-role=formula]",
               "Land on the Moon: mass × 1.62 × 0.033 − 42"
             )
    end

    test "starts closed and keeps the open state the browser sets", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      change(view, mission(28_801, land: :earth))

      refute has_element?(view, "#step-details-0[open]")
      assert ["ignore_attrs", %{"attrs" => ["open"]}] in mounted_js(view, "#step-details-0")
    end

    test "names each step for screen readers", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      change(view, mission(28_801, land: :moon, land: :earth))

      assert has_element?(view, "#step-details-0 summary .sr-only", "in step 1")
      assert has_element?(view, "#step-details-1 summary .sr-only", "in step 2")
    end

    test "says when a step needs no fuel", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      change(view, mission(100, land: :moon))

      assert has_element?(view, "#step-details-0 summary", "How 0 kg is calculated")
      assert has_element?(view, "#step-details-0 [data-role=iterations]", "No fuel needed")
    end

    test "shows a single iteration without a sum", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      change(view, mission(83, launch: :earth))

      assert has_element?(view, "#step-details-0 [data-role=iterations]", exactly("1 kg"))
      refute has_element?(view, "#step-details-0 [data-role=iterations]", "=")
    end

    test "shows every iteration of the heaviest step", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      change(view, mission(1_000_000_000_000, launch: :earth))

      assert has_element?(
               view,
               "#step-details-0 [data-role=iterations]",
               "411,893,999,967 + 169,656,667,189 + 69,880,563,242 + 28,783,384,683"
             )

      assert has_element?(
               view,
               "#step-details-0 [data-role=iterations]",
               "+ 1,324 + 512 + 177 + 39 = 700,373,740,645 kg"
             )
    end

    test "stays in every step while the mission is invalid", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      change(view, mission(28_801, land: :moon, land: nil))

      for index <- 0..1 do
        assert has_element?(view, "#step-details-#{index} summary", "How the fuel is calculated")

        assert has_element?(
                 view,
                 "#step-details-#{index}",
                 "Complete the mission to see the calculation"
               )
      end

      change(view, mission("", land: :moon))

      assert has_element?(view, "#step-details-0", "Complete the mission to see the calculation")
      refute has_element?(view, "#step-details-0 [data-role]")
    end
  end

  describe "flight path warnings" do
    @inconsistent_path [launch: :earth, land: :moon, launch: :mars, land: :earth, land: :mars]

    test "point out the steps that can't follow the previous one", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      change(view, mission(28_801, @inconsistent_path))

      assert has_element?(
               view,
               "#step-2 #step-warning-2:not([hidden])",
               "Launches from Mars, but step 2 landed on the Moon."
             )

      # The total says it once for the whole path
      refute has_element?(view, "#step-warning-2", "The fuel is still calculated.")

      assert has_element?(
               view,
               "#step-warning-4:not([hidden])",
               "Lands again without launching after step 4."
             )

      for index <- [0, 1, 3], do: assert(has_element?(view, "#step-warning-#{index}[hidden]"))
    end

    test "are announced by screen readers when they appear", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(view, "#step-0 [aria-live=polite] > #step-warning-0[hidden]")

      change(view, mission(28_801, @inconsistent_path))

      assert has_element?(view, "#step-2 [aria-live=polite] > #step-warning-2:not([hidden])")
      # The calculation changes on every keystroke, so it stays out of the live region
      refute has_element?(view, "[aria-live] [id^=step-details-]")
    end

    test "point out a launch right after another launch", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      change(view, mission(28_801, launch: :earth, launch: :moon))

      assert has_element?(
               view,
               "#step-warning-1:not([hidden])",
               "Launches again without landing after step 1."
             )
    end

    test "never appear for the example missions", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      for {id, _mass, _path, _total} <- @missions do
        load_example(view, id)

        refute has_element?(view, "[id^=step-warning-]:not([hidden])"), id
      end
    end

    test "don't change the fuel or the validation", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      change(view, mission(28_801, @inconsistent_path))

      total =
        FuelCalculatorWeb.MissionComponents.format_kg(Fuel.total(28_801, @inconsistent_path))

      assert has_element?(view, "#total-fuel", exactly(total))
      refute has_element?(view, "[aria-invalid]")
      refute has_element?(view, "#steps-errors")
    end

    test "appear without a valid mass, but not for incomplete steps", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      change(view, mission("", land: :moon, launch: :mars))
      assert has_element?(view, "#step-warning-1:not([hidden])")

      change(view, mission(28_801, land: :moon, launch: nil))

      refute has_element?(view, "[id^=step-warning-]:not([hidden])")
    end

    test "mark the step and the line that leads to it on the timeline", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      change(view, mission(28_801, @inconsistent_path))

      for index <- [2, 4] do
        assert has_element?(
                 view,
                 "#step-#{index} [data-role=step-icon].bg-warning .hero-exclamation-triangle-mini"
               )

        assert has_element?(view, "#step-#{index} > hr:first-child.bg-warning")
        assert has_element?(view, "#step-#{index - 1} > hr:last-child.bg-warning")
      end

      for index <- [0, 1, 3] do
        refute has_element?(view, "#step-#{index} [data-role=step-icon].bg-warning")
        refute has_element?(view, "#step-#{index} > hr:first-child.bg-warning")
      end

      refute has_element?(view, "#step-4 > hr:last-child.bg-warning")
    end

    test "mark the field that breaks the path", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      change(view, mission(28_801, @inconsistent_path))

      # Step 3 launches from another planet; step 5 lands twice
      assert has_element?(view, "#mission_steps_2_planet.select-warning")
      refute has_element?(view, "#mission_steps_2_action .ring-warning")
      assert has_element?(view, "#mission_steps_4_action .ring-warning")
      refute has_element?(view, "#mission_steps_4_planet.select-warning")

      for index <- [0, 1, 3] do
        refute has_element?(view, "#mission_steps_#{index}_planet.select-warning")
        refute has_element?(view, "#mission_steps_#{index}_action .ring-warning")
      end
    end

    test "are summed up in the fuel summary", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      change(view, mission(28_801, launch: :earth, launch: :moon))

      assert has_element?(
               view,
               "#fuel-warnings",
               exactly("Step 2 can't follow step 1. The total covers the steps as entered.")
             )

      refute has_element?(view, "#fuel-summary .stat-desc", "Includes the fuel to carry the fuel")
      assert has_element?(view, "#fuel-summary-steps .badge-warning", exactly("Warning: Step 2"))

      change(view, mission(28_801, @inconsistent_path))

      assert has_element?(
               view,
               "#fuel-warnings",
               exactly(
                 "2 steps can't follow the previous one. The total covers the steps as entered."
               )
             )

      assert has_element?(view, "#fuel-summary-steps .badge-warning", exactly("Warning: 2 steps"))

      for index <- [3, 5] do
        assert has_element?(
                 view,
                 "#fuel-by-step li:nth-child(#{index}) [data-role=label] .hero-exclamation-triangle-micro"
               )
      end

      for index <- [1, 2, 4] do
        refute has_element?(
                 view,
                 "#fuel-by-step li:nth-child(#{index}) .hero-exclamation-triangle-micro"
               )
      end
    end

    test "leave the fuel summary alone when the path can be flown", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      load_example(view, "apollo-11")

      refute has_element?(view, "#fuel-warnings")
      refute has_element?(view, "#fuel-summary .hero-exclamation-triangle-micro")
      assert has_element?(view, "#fuel-summary .stat-desc", "Includes the fuel to carry the fuel")
      assert has_element?(view, "#fuel-summary-steps", exactly("4 steps"))
    end

    test "describe the planet of the step", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      change(view, mission(28_801, land: :moon, launch: :mars))

      assert has_element?(view, "#mission_steps_1_planet[aria-describedby~=step-warning-1]")
      refute has_element?(view, "#mission_steps_0_planet[aria-describedby]")
    end
  end

  describe "quick fix" do
    test "is offered for each warning, named after the step it makes", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      change(view, mission(28_801, @inconsistent_path))

      assert has_element?(
               view,
               "#step-warning-2 #fix-step-2",
               exactly("Launch from the Moon instead")
             )

      assert has_element?(
               view,
               "#step-warning-4 #fix-step-4",
               exactly("Launch from Earth instead")
             )

      for index <- [0, 1, 3], do: refute(has_element?(view, "#fix-step-#{index}"))

      change(view, mission(28_801, launch: :earth, launch: :moon))
      assert has_element?(view, "#fix-step-1", exactly("Land on the Moon instead"))
    end

    test "changes the step so it follows the previous one", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      change(view, mission(28_801, launch: :earth, land: :moon, launch: :mars, land: :earth))
      view |> element("#fix-step-2") |> render_click()

      assert has_element?(
               view,
               "#step-2 [data-role=step-title]",
               exactly("3 · Launch from the Moon")
             )

      refute has_element?(view, "[id^=step-warning-]:not([hidden])")
      assert has_element?(view, "#total-fuel", exactly("51,898 kg"))

      change(view, mission(28_801, launch: :earth, land: :moon, land: :earth))
      view |> element("#fix-step-2") |> render_click()

      assert has_element?(
               view,
               "#step-2 [data-role=step-title]",
               exactly("3 · Launch from the Moon")
             )
    end

    test "focuses the field it changes", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      change(view, mission(28_801, @inconsistent_path))

      assert focus_target(view, "#fix-step-2") == "#mission_steps_2_planet"
      assert focus_target(view, "#fix-step-4") == "#mission_steps_4_action_launch"
    end

    test "keeps the rest of the mission as it is", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      # An invalid mass and a blank step added after the warning
      change(view, %{
        mission("abc", launch: :earth, launch: :moon)
        | "steps_sort" => ["0", "1", "new"]
      })

      assert has_element?(view, "#step-2")

      view |> element("#fix-step-1") |> render_click()

      assert has_element?(view, "#step-1 [data-role=step-title]", exactly("2 · Land on the Moon"))
      assert has_element?(view, "#mission_mass[value=abc]")
      assert has_element?(view, ".input-error #mission_mass")
      assert has_element?(view, "#step-2")
      refute has_element?(view, "#step-2 .select-error, #step-2 [aria-invalid]")
    end

    test "ignores a step without a warning or a crafted index", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      change(view, mission(28_801, launch: :earth, launch: :moon))
      html = render(view)

      for params <- [
            %{"index" => "0"},
            %{"index" => "2"},
            %{"index" => "-1"},
            %{"index" => "abc"},
            %{"index" => String.duplicate("1", 1000)},
            %{"index" => 1},
            %{}
          ] do
        render_hook(view, "fix_step", params)
        assert render(view) == html, inspect(params)
      end
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

      refute has_element?(view, ".input-error, .select-error, [aria-invalid]")
    end

    test "shows every error on submit, tied to its field", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      view
      |> element("#mission-form")
      |> render_submit(%{"mission" => %{"mass" => "", "steps_sort" => ["0"]}})

      assert has_element?(view, ".input-error #mission_mass")
      assert has_element?(view, "#mission_steps_0_action[aria-invalid]")
      assert has_element?(view, "#mission_steps_0_action-error", "can't be blank")
      assert has_element?(view, "#mission_steps_0_planet.select-error")

      for field <- ["mission_mass", "mission_steps_0_planet"] do
        assert has_element?(view, "##{field}[aria-invalid=true][aria-describedby=#{field}-error]")
        assert has_element?(view, "##{field}-error", "can't be blank")
      end
    end
  end

  describe "malformed events" do
    # render_hook sends the params as they are, without the form's inputs
    test "are ignored or rejected without crashing the view", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      change(view, mission(28_801, land: :earth))

      for {event, params} <- [
            {"validate", %{"mission" => "x"}},
            {"validate", %{}},
            {"load_example", %{}},
            {"unknown", %{"id" => "apollo-11"}}
          ] do
        render_hook(view, event, params)

        assert has_element?(view, "#total-fuel", exactly("13,447 kg")),
               "#{event} #{inspect(params)} changed the mission"
      end

      for params <- [
            %{"mass" => "28801", "steps_sort" => "x", "steps" => "x"},
            %{"mass" => "28801", "steps_drop" => "x", "steps" => %{"0" => ["x"]}},
            %{"mass" => %{"x" => "1"}, "steps" => [%{"action" => ["x"]}]},
            %{
              "mass" => ["28801"],
              "steps_swap" => %{},
              "steps" => %{
                "0" => %{"_persistent_id" => %{}, "action" => %{"x" => "1"}, "planet" => [%{}]}
              }
            }
          ] do
        render_hook(view, "validate", %{"mission" => params})

        assert has_element?(view, "#total-fuel", exactly("Not calculated yet")),
               "#{inspect(params)} was accepted"
      end

      change(view, mission(28_801, land: :earth))
      assert has_element?(view, "#total-fuel", exactly("13,447 kg"))
    end
  end

  # The LiveViewTest doesn't run JS commands, so these check the commands each element
  # carries; the focus itself was checked in a browser
  describe "focus" do
    test "moves to the step added with Add step, once", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      refute has_element?(view, "#steps > li[phx-mounted]")

      change(view, %{"mass" => "28801", "steps_sort" => ["0", "new"]})

      assert has_element?(view, "#step-1[phx-mounted]")
      refute has_element?(view, "#step-0[phx-mounted]")

      change(view, %{"mass" => "28802", "steps_sort" => ["0", "1"]})

      refute has_element?(view, "#steps > li[phx-mounted]")
    end

    test "stays put when an example is loaded", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      change(view, %{"mass" => "28801", "steps_sort" => ["0", "new"]})
      load_example(view, "apollo-11")

      refute has_element?(view, "#steps > li[phx-mounted]")
    end

    test "moves to Add step when the only step is removed", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      assert focus_target(view, "#remove-step-0") == "#add-step"
    end

    test "moves to the previous step's remove button on removal", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      load_example(view, "apollo-11")

      # The first step's button becomes the next step's, so the focus stays on it
      assert focus_target(view, "#remove-step-0") == nil
      assert focus_target(view, "#remove-step-1") == "#remove-step-0"
      assert focus_target(view, "#remove-step-3") == "#remove-step-2"
    end

    test "follows the moved step", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      load_example(view, "apollo-11")

      assert focus_target(view, "#move-step-up-2") == "#move-step-up-1"
      assert focus_target(view, "#move-step-down-1") == "#move-step-down-2"
      # A step moved to an end gets the button that is still enabled
      assert focus_target(view, "#move-step-up-1") == "#move-step-down-0"
      assert focus_target(view, "#move-step-down-2") == "#move-step-up-3"
    end
  end

  # The add, move and remove buttons trigger a form change through JS, which
  # LiveViewTest does not run, so these tests send the steps_sort, steps_swap and
  # steps_drop values the buttons add to the form. Moved steps are checked by row,
  # since inputs_for keeps each step's input ids when it changes position.
  describe "flight path" do
    test "adds a blank step and keeps the entered values", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      change(view, %{mission(28_801, land: :earth) | "steps_sort" => ["0", "new"]})

      assert has_element?(view, "#mission_mass[value='28801']")
      assert has_element?(view, "#mission_steps_0_action input[value='land'][checked]")
      assert has_element?(view, "#mission_steps_0_planet option[value='earth'][selected]")
      assert has_element?(view, "#step-1")
      refute has_element?(view, "#step-1 option[selected], #step-1 input[checked]")
    end

    test "wires Add step and the remove buttons to steps_sort and steps_drop", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      change(view, mission(28_801, land: :earth, launch: :moon))

      assert has_element?(view, "#add-step[name='mission[steps_sort][]'][value='new']")
      assert has_element?(view, "#remove-step-0[name='mission[steps_drop][]'][value='0']")
      assert has_element?(view, "#remove-step-1[name='mission[steps_drop][]'][value='1']")
    end

    test "removes a step", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      change(view, Map.put(mission(28_801, land: :moon, land: :earth), "steps_drop", ["0"]))

      assert has_element?(view, "#step-0")
      refute has_element?(view, "#step-1")
      assert has_element?(view, "#total-fuel", exactly("13,447 kg"))
    end

    test "removing the only step leaves an empty path that needs no fuel", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      change(view, %{"mass" => "28801", "steps_sort" => ["0"], "steps_drop" => ["0"]})

      refute has_element?(view, "#step-0")
      assert has_element?(view, "#empty-path")
      assert has_element?(view, "#total-fuel", exactly("0 kg"))
      refute has_element?(view, "#fuel-by-step")
    end

    test "hides the empty path message once a step is added", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      change(view, %{"mass" => "28801", "steps_sort" => ["0"], "steps_drop" => ["0"]})
      change(view, %{"mass" => "28801", "steps_sort" => ["new"]})

      assert has_element?(view, "#step-0")
      refute has_element?(view, "#empty-path")
    end

    test "moves a step down", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      change(view, mission(28_801, land: :earth, launch: :moon))
      assert has_element?(view, "#total-fuel", exactly("16,436 kg"))
      assert has_element?(view, "#step-0 #step-details-0 summary", "How 14,412 kg is")
      assert has_element?(view, "#step-1 #step-details-1 summary", "How 2,024 kg is")

      change(view, Map.put(mission(28_801, land: :earth, launch: :moon), "steps_swap", "0"))

      assert has_element?(view, "#step-0 input[value='launch'][checked]")
      assert has_element?(view, "#step-0 option[value='moon'][selected]")
      assert has_element?(view, "#step-1 input[value='land'][checked]")
      assert has_element?(view, "#step-1 option[value='earth'][selected]")
      assert has_element?(view, "#step-0 #step-details-0 summary", "How 3,001 kg is")
      assert has_element?(view, "#step-1 #step-details-1 summary", "How 13,447 kg is")
      assert has_element?(view, "#total-fuel", exactly("16,448 kg"))
    end

    test "ignores a move outside the flight path", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      for swap <- ["-1", "1", "2", "abc", "0.5", ""] do
        change(view, Map.put(mission(28_801, land: :earth, launch: :moon), "steps_swap", swap))

        assert has_element?(view, "#step-0 input[value='land'][checked]"),
               "steps_swap #{inspect(swap)} moved a step"

        assert has_element?(view, "#step-1 input[value='launch'][checked]"),
               "steps_swap #{inspect(swap)} moved a step"
      end
    end

    # Parsing an integer this long raises a system limit error
    test "ignores a move position too long to be a step", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      swap = String.duplicate("1", 1_300_000)
      change(view, Map.put(mission(28_801, land: :earth, launch: :moon), "steps_swap", swap))

      assert has_element?(view, "#step-0 input[value='land'][checked]")
      assert has_element?(view, "#step-1 input[value='launch'][checked]")
    end

    # render_hook sends the params as they are, without the form's inputs
    test "ignores a move that is not a single position or has no order", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      for params <- [
            Map.put(mission(28_801, land: :earth, launch: :moon), "steps_swap", ["0"]),
            mission(28_801, land: :earth, launch: :moon)
            |> Map.delete("steps_sort")
            |> Map.put("steps_swap", "0")
          ] do
        render_hook(view, "validate", %{"mission" => params})

        assert has_element?(view, "#step-0 input[value='land'][checked]"),
               "#{inspect(params)} moved a step"

        assert has_element?(view, "#step-1 input[value='launch'][checked]"),
               "#{inspect(params)} moved a step"
      end
    end

    test "wires the move buttons to the position of the upper step", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      change(view, mission(28_801, land: :earth, launch: :moon, land: :moon))

      assert has_element?(view, "#move-step-up-1[name='mission[steps_swap]'][value='0']")
      assert has_element?(view, "#move-step-down-1[name='mission[steps_swap]'][value='1']")
      assert has_element?(view, "#move-step-up-2[value='1']")
      assert has_element?(view, "#move-step-down-0[value='0']")
    end

    test "moves a step without showing errors on fields the user has not touched", %{
      conn: conn
    } do
      {:ok, view, _html} = live(conn, ~p"/")

      change(view, %{
        "mass" => "28801",
        "steps_sort" => ["0", "1"],
        "steps_swap" => "0",
        "steps" => %{
          "0" => %{"action" => "land", "planet" => "earth"},
          "1" => %{"_unused_action" => "", "action" => "", "_unused_planet" => "", "planet" => ""}
        }
      })

      assert has_element?(view, "#step-1 input[value='land'][checked]")
      refute has_element?(view, ".input-error, .select-error, [aria-invalid]")
    end

    test "disables moving the first step up and the last step down", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      change(view, mission(28_801, land: :earth, launch: :moon))

      assert has_element?(view, "#move-step-up-0[disabled]")
      refute has_element?(view, "#move-step-down-0[disabled]")
      refute has_element?(view, "#move-step-up-1[disabled]")
      assert has_element?(view, "#move-step-down-1[disabled]")
    end

    test "counts the steps left only close to the limit", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      refute has_element?(view, "#steps-left")

      change(view, mission(28_801, List.duplicate({:land, :moon}, 11)))
      refute has_element?(view, "#steps-left")

      change(view, mission(28_801, List.duplicate({:land, :moon}, 12)))
      assert has_element?(view, "#steps-left", exactly("3 more steps allowed"))

      change(view, mission(28_801, List.duplicate({:land, :moon}, 14)))
      assert has_element?(view, "#steps-left", exactly("1 more step allowed"))

      change(view, mission(28_801, List.duplicate({:land, :moon}, 15)))
      refute has_element?(view, "#steps-left")
      assert has_element?(view, "#step-limit")
    end

    test "starts with the spacecraft and ends with Add step", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(view, "h2", "Flight path")
      assert has_element?(view, "[data-role=spacecraft] #mission_mass")
      assert has_element?(view, "#steps + ul #add-step")
      # The mass is not one of the steps, so screen readers don't announce it in their group
      assert has_element?(view, "#flight-path-steps > legend", "Steps")
      refute has_element?(view, "fieldset #mission_mass")
      # The timeline's lines are decoration, not separators
      assert has_element?(view, "#steps hr[aria-hidden=true]")
      refute has_element?(view, "hr:not([aria-hidden=true])")
    end

    test "lists only the steps for screen readers", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      change(view, mission(28_801, land: :moon, launch: :moon))

      assert has_element?(view, "ul[role=none] > li[role=none][data-role=spacecraft]")
      assert has_element?(view, "#steps + ul[role=none] > li[role=none] #add-step")
      assert has_element?(view, "#steps > li#step-1")
      refute has_element?(view, "#steps > li:not([id^=step-]), #steps > li[role]")
    end

    test "keeps only list items in the steps list", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      change(view, mission(28_801, land: :moon, launch: :moon))

      refute has_element?(view, "#steps > :not(li)")

      for index <- [0, 1] do
        assert has_element?(
                 view,
                 "#step-#{index} input[type=hidden][name='mission[steps][#{index}][_persistent_id]']"
               )
      end
    end

    test "disables adding a step at 15 steps", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      change(view, mission(28_801, List.duplicate({:land, :moon}, 14)))
      refute has_element?(view, "#add-step[disabled]")
      refute has_element?(view, "#step-limit")

      change(view, mission(28_801, List.duplicate({:land, :moon}, 15)))

      assert has_element?(view, "#step-14")
      assert has_element?(view, "#add-step[disabled]")
      assert has_element?(view, "#step-limit", "15 steps")
      refute has_element?(view, "#steps-errors")
    end

    test "rejects more than 15 steps", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      change(view, mission(28_801, List.duplicate({:land, :moon}, 16)))

      assert has_element?(view, "#steps-errors", "should have at most 15 item(s)")
      assert has_element?(view, "#total-fuel", exactly("Not calculated yet"))
      assert has_element?(view, "#fuel-pending p", exactly("Fix the errors in the flight path"))
      refute has_element?(view, "#fuel-pending-go")

      change(view, mission(28_801, land: :earth))

      refute has_element?(view, "#steps-errors")
      assert has_element?(view, "#total-fuel", exactly("13,447 kg"))
    end

    test "marks the chosen action and only it", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      change(view, mission(28_801, land: :earth))

      # The labels follow the radios' :checked in CSS, so the radios carry the state
      assert has_element?(view, "#mission_steps_0_action_land[checked]")
      refute has_element?(view, "#mission_steps_0_action_launch[checked]")
    end

    test "titles each step with its number, action and planet", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      change(view, mission(28_801, launch: :earth, land: :moon))

      assert has_element?(
               view,
               "#step-0 [data-role=step-title]",
               exactly("1 · Launch from Earth")
             )

      assert has_element?(view, "#step-1 [data-role=step-title]", exactly("2 · Land on the Moon"))
    end

    test "asks for the action and the planet of an incomplete step", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(
               view,
               "#step-0 [data-role=step-title]",
               exactly("1 · Choose an action and a planet")
             )

      change(view, mission(28_801, land: :moon, land: nil))

      assert has_element?(
               view,
               "#step-1 [data-role=step-title]",
               exactly("2 · Choose an action and a planet")
             )
    end

    test "marks each step with the icon of its action", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(view, "#step-0 [data-role=step-icon] .hero-ellipsis-horizontal")

      change(view, mission(28_801, launch: :earth, land: :moon))

      assert has_element?(view, "#step-0 [data-role=step-icon] .hero-arrow-up-right")
      assert has_element?(view, "#step-1 [data-role=step-icon] .hero-arrow-down-right")
    end

    test "colors the spacecraft once its mass is valid", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      refute has_element?(view, "[data-role=spacecraft-icon].bg-primary")

      change(view, %{"mass" => "28801"})
      assert has_element?(view, "[data-role=spacecraft-icon].bg-primary")

      change(view, %{"mass" => "0"})
      refute has_element?(view, "[data-role=spacecraft-icon].bg-primary")
    end
  end

  defp focus_target(view, button) do
    view
    |> query(button)
    |> LazyHTML.attribute("phx-click")
    |> hd()
    |> JSON.decode!()
    |> Enum.find_value(fn [kind, args] -> if kind == "focus", do: args["to"] end)
  end

  defp mounted_js(view, selector) do
    view
    |> query(selector)
    |> LazyHTML.attribute("phx-mounted")
    |> hd()
    |> JSON.decode!()
  end

  # has_element?/3 matches text anywhere in the element, so "1 kg" would match "31 kg"
  defp exactly(text), do: ~r/^\s*#{Regex.escape(text)}\s*$/

  defp query(view, selector) do
    view |> render() |> LazyHTML.from_fragment() |> LazyHTML.query(selector)
  end

  defp load_example(view, id), do: view |> element("#example-#{id}") |> render_click()

  defp change(view, params) do
    view
    |> element("#mission-form")
    |> render_change(%{"mission" => params})
  end

  defp texts(view, selector) do
    view
    |> query(selector)
    |> Enum.map(&(&1 |> LazyHTML.text() |> String.trim()))
  end

  defp current_examples(view) do
    view
    |> query("[id^=example-][aria-current=true]")
    |> LazyHTML.attribute("id")
  end

  defp option_values(view, select) do
    view
    |> query("#{select} option")
    |> LazyHTML.attribute("value")
  end

  defp radio_values(view, group) do
    view
    |> query("#{group} input[type=radio]")
    |> LazyHTML.attribute("value")
  end

  # A nil action or planet leaves that field blank, as in an incomplete step
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
