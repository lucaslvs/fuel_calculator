defmodule FuelCalculatorWeb.MissionLiveTest do
  use FuelCalculatorWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias FuelCalculator.Fuel

  # The missions of the challenge, also offered as examples (by id)
  @missions [
    {"apollo-11", 28_801, [launch: :earth, land: :moon, launch: :moon, land: :earth],
     "51,898 kg"},
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
      refute has_element?(view, "#empty-path:not([hidden])")
      assert has_element?(view, "#total-fuel", "—")
      refute has_element?(view, ".input-error, .select-error, [aria-invalid]")
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

      assert has_element?(view, "#total-fuel", "—")
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
      assert has_element?(view, "#step-fuel-0", exactly("1,035,490,598,312 kg"))
    end

    test "is announced to screen readers when it changes", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(view, "#total-fuel[aria-live=polite][aria-atomic=true]")
      assert has_element?(view, "#total-fuel [aria-hidden=true]", "—")
      assert has_element?(view, "#total-fuel .sr-only", "not available yet")

      change(view, mission(28_801, land: :earth))

      refute has_element?(view, "#total-fuel .sr-only")
    end

    test "is cleared when the mass becomes invalid", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      for mass <- ["0", "-1", "abc", "1000000000001"] do
        change(view, mission(28_801, land: :earth))
        assert has_element?(view, "#total-fuel", exactly("13,447 kg"))

        change(view, mission(mass, land: :earth))

        assert has_element?(view, ".input-error #mission_mass"), "mass #{inspect(mass)}"
        assert has_element?(view, "#total-fuel", "—"), "mass #{inspect(mass)}"
      end
    end

    test "is cleared when a step becomes incomplete", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      change(view, mission(28_801, land: :earth))
      assert has_element?(view, "#total-fuel", exactly("13,447 kg"))

      change(view, %{
        "mass" => "28801",
        "steps_sort" => ["0"],
        "steps" => %{"0" => %{"action" => "land", "planet" => ""}}
      })

      assert has_element?(view, "#mission_steps_0_planet.select-error")
      assert has_element?(view, "#total-fuel", "—")
    end

    test "is shown once, with the number of steps", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(view, "#fuel-summary-steps", "Complete the mission")

      change(view, mission(28_801, land: :earth))
      assert has_element?(view, "#fuel-summary-steps", "1 step")

      view |> element("#example-apollo-11") |> render_click()
      assert has_element?(view, "#fuel-summary-steps", "4 steps")

      assert view
             |> render()
             |> LazyHTML.from_fragment()
             |> LazyHTML.query("#total-fuel")
             |> Enum.count() == 1
    end
  end

  describe "examples" do
    for {id, mass, path, total} <- @missions do
      test "loads the #{id} mission", %{conn: conn} do
        {:ok, view, _html} = live(conn, ~p"/")

        view |> element("#example-#{unquote(id)}") |> render_click()

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

      view |> element("#example-passenger-ship") |> render_click()
      assert has_element?(view, "#step-5")

      view |> element("#example-mars") |> render_click()

      assert has_element?(view, "#step-3")
      refute has_element?(view, "#step-4")
      refute has_element?(view, ".input-error, .select-error, [aria-invalid]")
      assert has_element?(view, "#total-fuel", exactly("33,388 kg"))
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
    test "is shown for each step of a valid mission", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      change(view, mission(28_801, launch: :earth, land: :moon, launch: :moon, land: :earth))

      for {fuel, index} <- Enum.with_index(["32,988 kg", "2,462 kg", "3,001 kg", "13,447 kg"]) do
        assert has_element?(view, "#step-#{index} #step-fuel-#{index}", exactly(fuel))
      end
    end

    test "is hidden while the mission is invalid", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      change(view, mission(28_801, land: :moon, land: :earth))
      assert has_element?(view, "#step-fuel-1")

      change(view, mission("", land: :moon, land: :earth))

      refute has_element?(view, "[id^=step-fuel-]")
    end

    test "is hidden while a step is incomplete", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      change(view, %{
        "mass" => "28801",
        "steps_sort" => ["0", "1"],
        "steps" => %{
          "0" => %{"action" => "land", "planet" => "moon"},
          "1" => %{"action" => "land", "planet" => ""}
        }
      })

      refute has_element?(view, "[id^=step-fuel-]")
    end
  end

  describe "fuel explanation" do
    test "shows the mass, the formula and the iterations of each step", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      change(view, mission(28_801, launch: :earth, land: :moon, launch: :moon, land: :earth))

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

      change(view, %{
        "mass" => "28801",
        "steps_sort" => ["0", "1"],
        "steps" => %{
          "0" => %{"action" => "land", "planet" => "moon"},
          "1" => %{"action" => "land", "planet" => ""}
        }
      })

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

      assert has_element?(view, "#step-warning-2", "The fuel is still calculated.")

      assert has_element?(
               view,
               "#step-warning-4:not([hidden])",
               "Lands again without launching after step 4."
             )

      for index <- [0, 1, 3], do: assert(has_element?(view, "#step-warning-#{index}[hidden]"))
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
        view |> element("#example-#{id}") |> render_click()

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

      change(view, %{
        "mass" => "28801",
        "steps_sort" => ["0", "1"],
        "steps" => %{
          "0" => %{"action" => "land", "planet" => "moon"},
          "1" => %{"action" => "launch", "planet" => ""}
        }
      })

      refute has_element?(view, "[id^=step-warning-]:not([hidden])")
    end

    test "describe the planet of the step", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      change(view, mission(28_801, land: :moon, launch: :mars))

      assert has_element?(view, "#mission_steps_1_planet[aria-describedby~=step-warning-1]")
      refute has_element?(view, "#mission_steps_0_planet[aria-describedby]")
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

    test "shows every error on submit", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      view
      |> element("#mission-form")
      |> render_submit(%{"mission" => %{"mass" => "", "steps_sort" => ["0"]}})

      assert has_element?(view, ".input-error #mission_mass")
      assert has_element?(view, "#mission_steps_0_action[aria-invalid]")
      assert has_element?(view, "#mission_steps_0_action-error", "can't be blank")
      assert has_element?(view, "#mission_steps_0_planet.select-error")
    end

    test "ties each error to its field", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      view
      |> element("#mission-form")
      |> render_submit(%{"mission" => %{"mass" => "", "steps_sort" => ["0"]}})

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

        assert has_element?(view, "#total-fuel", "—"), "#{inspect(params)} was accepted"
      end

      change(view, mission(28_801, land: :earth))
      assert has_element?(view, "#total-fuel", exactly("13,447 kg"))
    end
  end

  # The add, move and remove buttons trigger a form change through JS, which
  # LiveViewTest does not run, so these tests send the steps_sort, steps_swap and
  # steps_drop values the buttons add to the form. Moved steps are checked by row,
  # since inputs_for keeps each step's input ids when it changes position.
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
      view |> element("#example-apollo-11") |> render_click()

      refute has_element?(view, "#steps > li[phx-mounted]")
    end

    test "moves to Add step when the only step is removed", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      assert focus_target(view, "#remove-step-0") == "#add-step"
    end

    test "keeps the empty state in the page while there are steps", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      # Inserting it when the last step is removed would move "Add step" and drop its focus
      assert has_element?(view, "#empty-path[hidden]")
    end

    test "moves to the previous step's remove button on removal", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      view |> element("#example-apollo-11") |> render_click()

      # The first step's button becomes the next step's, so the focus stays on it
      assert focus_target(view, "#remove-step-0") == nil
      assert focus_target(view, "#remove-step-1") == "#remove-step-0"
      assert focus_target(view, "#remove-step-3") == "#remove-step-2"
    end

    test "follows the moved step", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      view |> element("#example-apollo-11") |> render_click()

      assert focus_target(view, "#move-step-up-2") == "#move-step-up-1"
      assert focus_target(view, "#move-step-down-1") == "#move-step-down-2"
      # A step moved to an end gets the button that is still enabled
      assert focus_target(view, "#move-step-up-1") == "#move-step-down-0"
      assert focus_target(view, "#move-step-down-2") == "#move-step-up-3"
    end
  end

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

    test "adds and removes steps through the order and removal params", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      change(view, mission(28_801, land: :earth, launch: :moon))

      assert has_element?(view, "#add-step[name='mission[steps_sort][]'][value='new']")
      assert has_element?(view, "#remove-step-0[name='mission[steps_drop][]'][value='0']")
      assert has_element?(view, "#remove-step-1[name='mission[steps_drop][]'][value='1']")
    end

    test "removes a step", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      change(view, mission(28_801, land: :moon, land: :earth))
      change(view, Map.put(mission(28_801, land: :moon, land: :earth), "steps_drop", ["0"]))

      assert has_element?(view, "#step-0")
      refute has_element?(view, "#step-1")
      assert has_element?(view, "#total-fuel", exactly("13,447 kg"))
    end

    test "removing the only step leaves an empty path that needs no fuel", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      change(view, %{"mass" => "28801", "steps_sort" => ["0"], "steps_drop" => ["0"]})

      refute has_element?(view, "#step-0")
      assert has_element?(view, "#empty-path:not([hidden])")
      assert has_element?(view, "#total-fuel", exactly("0 kg"))
    end

    test "hides the empty path message once a step is added", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      change(view, %{"mass" => "28801", "steps_sort" => ["0"], "steps_drop" => ["0"]})
      change(view, %{"mass" => "28801", "steps_sort" => ["new"]})

      assert has_element?(view, "#step-0")
      refute has_element?(view, "#empty-path:not([hidden])")
    end

    test "moves a step down", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      change(view, mission(28_801, land: :earth, launch: :moon))
      assert has_element?(view, "#total-fuel", exactly("16,436 kg"))
      assert has_element?(view, "#step-0 #step-fuel-0", exactly("14,412 kg"))
      assert has_element?(view, "#step-1 #step-fuel-1", exactly("2,024 kg"))

      change(view, Map.put(mission(28_801, land: :earth, launch: :moon), "steps_swap", "0"))

      assert has_element?(view, "#step-0 input[value='launch'][checked]")
      assert has_element?(view, "#step-0 option[value='moon'][selected]")
      assert has_element?(view, "#step-1 input[value='land'][checked]")
      assert has_element?(view, "#step-1 option[value='earth'][selected]")
      assert has_element?(view, "#step-0 #step-fuel-0", exactly("3,001 kg"))
      assert has_element?(view, "#step-1 #step-fuel-1", exactly("13,447 kg"))
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

    test "moves a step up or down by sending the position of the upper step", %{conn: conn} do
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
      assert has_element?(view, "#total-fuel", "—")

      change(view, mission(28_801, land: :earth))

      refute has_element?(view, "#steps-errors")
      assert has_element?(view, "#total-fuel", exactly("13,447 kg"))
    end

    test "marks the chosen action and only it", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      change(view, mission(28_801, land: :earth))

      assert has_element?(view, "#mission_steps_0_action_land[checked]")
      refute has_element?(view, "#mission_steps_0_action_launch[checked]")
      assert has_element?(view, "label[for=mission_steps_0_action_land].btn-primary")
      refute has_element?(view, "label[for=mission_steps_0_action_launch].btn-primary")
    end

    test "titles each step with its number, action and planet", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      change(view, mission(28_801, launch: :earth, land: :moon))

      refute has_element?(view, "#empty-path:not([hidden])")

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

      change(view, %{
        "mass" => "28801",
        "steps_sort" => ["0", "1"],
        "steps" => %{
          "0" => %{"action" => "land", "planet" => "moon"},
          "1" => %{"action" => "land", "planet" => ""}
        }
      })

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
  end

  defp focus_target(view, button) do
    view
    |> render()
    |> LazyHTML.from_fragment()
    |> LazyHTML.query(button)
    |> LazyHTML.attribute("phx-click")
    |> hd()
    |> JSON.decode!()
    |> Enum.find_value(fn [kind, args] -> if kind == "focus", do: args["to"] end)
  end

  defp mounted_js(view, selector) do
    view
    |> render()
    |> LazyHTML.from_fragment()
    |> LazyHTML.query(selector)
    |> LazyHTML.attribute("phx-mounted")
    |> hd()
    |> JSON.decode!()
  end

  # has_element?/3 matches text anywhere in the element, so "1 kg" would match "31 kg"
  defp exactly(text), do: ~r/^\s*#{Regex.escape(text)}\s*$/

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

  defp radio_values(view, group) do
    view
    |> render()
    |> LazyHTML.from_fragment()
    |> LazyHTML.query("#{group} input[type=radio]")
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
