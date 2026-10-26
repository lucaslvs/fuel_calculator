# FuelCalculator

[![CI](https://github.com/lucaslvs/fuel_calculator/actions/workflows/ci.yml/badge.svg)](https://github.com/lucaslvs/fuel_calculator/actions/workflows/ci.yml)
[![Deploy](https://img.shields.io/endpoint?url=https://gist.githubusercontent.com/lucaslvs/92a585ac99ba97b6bca7818f6e6da8f9/raw/fuel_calculator-deploy.json)](https://fuel-calculator.gigalixirapp.com)
[![Coverage](https://img.shields.io/endpoint?url=https://gist.githubusercontent.com/lucaslvs/92a585ac99ba97b6bca7818f6e6da8f9/raw/fuel_calculator-coverage.json)](https://github.com/lucaslvs/fuel_calculator/actions/workflows/ci.yml)

A Phoenix LiveView application that calculates the fuel required for interplanetary
flight paths (launches and landings on Earth, Moon and Mars).

Live demo: <https://fuel-calculator.gigalixirapp.com> (hosted on Gigalixir's free
tier, deployed automatically from `main` after CI passes).

## Using the app

- **Example missions:** the three missions from the challenge are cards at the
  top. One click loads their mass and flight path, and the total matches the
  challenge (Apollo 11: 51,898 kg). Editing any value unmarks the card.
- **Guided flight path:** the page opens with only the spacecraft mass. Once the
  mass is valid, *Add step* offers *Launch* or *Land*; the new step starts with
  that action and asks for a planet, and the next step can be added once it has
  one. Any step can be changed or removed, up to 15 steps.
- **Real-time total:** the total fuel is recalculated on every change (the mass
  field waits for a pause in typing). While the mission is incomplete, the
  summary says what to fill in next instead of a total.
- **Fuel by step:** the summary breaks the total down by step (on small screens,
  in a bar at the bottom). Each step also explains its fuel: the mass it carries
  (the spacecraft plus the fuel for the later steps), the formula, and the
  iterations, as the challenge writes them (9,278 + 2,960 + 915 + 254 + 40 =
  13,447 kg).
- **Warnings:** a step that can't follow the previous one (two landings or two
  launches in a row, or a launch from a planet other than the last landing) is
  marked on the flight path and in the summary, with a one-click fix. The fuel
  is still calculated for the steps as entered.
- **Validation:** the mass is a whole number from 1 to 1,000,000,000,000 kg (its
  digits are grouped as it is typed), and every step needs an action and a
  planet. Errors show next to their field.

## Requirements

- Erlang/OTP 29.1.2 and Elixir 1.20.4 (pinned in `.tool-versions`; works with
  [mise](https://mise.jdx.dev) or [asdf](https://asdf-vm.com))
- No database required
- Node 20 or later, only for the browser tests

## Getting started

```sh
mise install        # or: asdf install
mix setup
mix phx.server
```

Then open [`localhost:4000`](http://localhost:4000).

## Quality checks

```sh
mix precommit     # compile --warnings-as-errors, format, credo --strict, test --cover
mix test --cover  # test coverage (90% threshold, HTML report in cover/)
mix dialyzer      # static type analysis
```

The browser tests run the page's JavaScript in Chromium through
[Playwright](https://playwright.dev), so they need Node and are left out of
`mix test`. Playwright is installed in `test/browser/`, out of `assets/`, so the
production build doesn't install it:

```sh
npm ci --prefix test/browser
test/browser/node_modules/.bin/playwright install chromium
mix test.browser  # builds the assets and runs the tests tagged :e2e with the server on
PW_TRACE=true mix test.browser --failed  # reruns the failures with a trace in tmp/traces
```

A trace replays the test step by step, with the page at each step:
`test/browser/node_modules/.bin/playwright show-trace tmp/traces/<file>.zip`. In CI
every browser test records one, and the traces of a failed run are uploaded as an
artifact.

The same checks run on every push via GitHub Actions, and the build fails below
90% coverage. The workflow also publishes a per-module coverage summary, updates
the coverage badge, lints itself with [actionlint](https://github.com/rhysd/actionlint)
and fails when a Hex dependency is retired or has a security advisory
(`mix hex.audit`). The browser tests run in a job of their own, and the deploy
waits for both.

## Project structure

| Module | Responsibility |
| ------ | -------------- |
| [`FuelCalculator.Planet`](lib/fuel_calculator/planet.ex) | The supported planets and their gravity |
| [`FuelCalculator.Fuel`](lib/fuel_calculator/fuel.ex) | The launch and landing formulas, the fuel for the fuel, and each step's iterations |
| [`FuelCalculator.FlightPath`](lib/fuel_calculator/flight_path.ex) | Warnings for steps that can't follow the previous one, and their fixes |
| [`FuelCalculator.Mission`](lib/fuel_calculator/mission.ex), [`Mission.Step`](lib/fuel_calculator/mission/step.ex) | Validate the form input and calculate the mission's fuel |
| [`FuelCalculatorWeb.MissionLive`](lib/fuel_calculator_web/live/mission_live.ex) | The page at `/`: form events, example missions, recalculation on every change |
| [`FuelCalculatorWeb.MissionComponents`](lib/fuel_calculator_web/components/mission_components.ex) | Example cards, flight path timeline, step rows and fuel summary |
| [`FuelCalculatorWeb.ErrorHTML`](lib/fuel_calculator_web/controllers/error_html.ex) | 404 and 500 pages in the app's look |

The calculation and the validation (`lib/fuel_calculator/`) don't depend on the
web layer. `CoreComponents` and `Layouts` are Phoenix's generated ones, trimmed
to what the app uses.

## Design decisions

### Domain

- `Fuel` and `Planet` are pure functions with no processes: the calculation has
  no state, I/O or concurrency to manage.
- A flight path is calculated from the last step to the first, because each step
  carries the fuel of every later step as extra weight.
- The fuel is calculated with integers: gravities and the formula's factors are
  kept in thousandths, so rounding down is exact. With floats, as the challenge
  writes the formulas, a result a hair below an integer can round up near
  10^12 kg (601,183,387,170 kg launching from Earth needs 2 kg more than the
  exact value). Mass is capped at 10^12 kg.

### Validation

- `Mission` and `Mission.Step` are Ecto embedded schemas validated with
  changesets; there is no database.
- Actions and planets are `Ecto.Enum` fields, so form input is cast to known
  atoms and never converted with `String.to_atom/1`.
- An empty flight path is valid and needs 0 kg of fuel, though the page asks for
  a first step instead of showing that total. New steps start with the action
  they were added with and no planet, so a step without a planet shows an error
  instead of a silent default.
- A flight path has at most 15 steps. Longer params are rejected before Ecto
  casts them, and the LiveView websocket accepts frames up to 64 KB, so a crafted
  request cannot make the server build thousands of steps.

### LiveView

- A single LiveView at `/` renders the calculator and needs no parameters.
- Steps are added and removed through Ecto's `sort_param` and
  `drop_param` with `<.inputs_for>`: the form params are the only state, and
  the only custom JavaScript is a colocated hook that groups the mass digits as
  they are typed.
- The flight path is a regular assign, not a stream: it is a short list, and the
  total is recalculated over all of it on every change.
- Change and submit share one event, so pressing Enter recalculates and shows
  every error instead of posting the form.
- The fuel of each step appears only when the whole mission is valid, since each
  step depends on the steps after it.

### Security

- Pages are served with a strict Content-Security-Policy: scripts, styles,
  images and connections come only from the app's own origin and its websocket,
  and the pages have no inline scripts. There is a single dark theme, so no
  script has to apply a theme before the page renders. Development keeps
  Phoenix's default policy, since the Tidewave toolbar and the error pages rely
  on inline code.
- The font (IBM Plex Sans, OFL-1.1) is served from `priv/static/fonts`
  for the same reason: the policy doesn't allow a font CDN. Only the latin subset
  is included, which covers every character the UI uses.
- The sky behind the page is CSS over SVGs in `priv/static/images`: star tiles
  (colors from Mitchell Charity's star color table) and fractal-noise masks for
  the nebula, painted in the theme colors. The policy covers them as images.

### Quality

- The three scenarios from the challenge are tested in the domain, the
  validation and the LiveView.
- Tests mirror `lib/` in `test/`:
  - `fuel_test.exs`: the formulas, the iterations and the breakdown by step,
    plus a regression test for the float rounding above;
  - `fuel_properties_test.exs`: StreamData properties: the total and each step
    match an exact model built from the challenge's decimal figures, and more
    mass never needs less fuel;
  - `flight_path_test.exs`: warnings and fixes, with properties;
  - `mission_test.exs` and `mission/step_test.exs`: validation, including the
    mass bounds and the step limit;
  - `live/mission_live_test.exs`: the page through `Phoenix.LiveViewTest`:
    examples, adding and removing steps, the total, the explanations, warnings
    and fixes, errors, focus and crafted events;
  - `browser/`: the page's JavaScript in Chromium, which `Phoenix.LiveViewTest`
    doesn't run (`BrowserCase` fails a test when the page logs an error, such
    as one the security policy blocked): a quick fix shows the planet the fuel
    is calculated with and focuses its field, and the mass field groups digits
    while typing but keeps a sign or a decimal point for the server to reject;
  - the other files under `fuel_calculator_web/`: the security policy, request
    size limits, static files and error pages.
- CI compiles with warnings as errors, runs Credo in strict mode, Dialyzer, the
  tests and `mix hex.audit`, and fails below 90% coverage.

### Hosting

- Gigalixir's free tier was the only zero-cost option found that keeps an
  instance always on, so the demo has no cold start.

## Deployment

The app runs on [Gigalixir](https://www.gigalixir.com)'s free tier at
<https://fuel-calculator.gigalixirapp.com>, which keeps one instance always on
(no cold start when someone opens the link).

Every push to `main` that passes CI is deployed by the `deploy` job in
[`.github/workflows/ci.yml`](.github/workflows/ci.yml), which:

1. pushes the commit to Gigalixir, which builds an Elixir release with its
   buildpacks (versions from `.tool-versions`, assets via `mix assets.deploy`);
2. waits until every instance runs that commit and reports healthy;
3. smoke tests the home page and the LiveView websocket upgrade.

A run whose commit is no longer the tip of `main` skips the deploy, since the
run of the newer commit deploys it; otherwise two pushes close together could
leave the older one in production.

Changes that only touch documentation (`*.md`, `docs/`) skip CI and deployment.
The same job also redeploys `main` on the 1st and 15th of each month, because
Gigalixir's free tier scales apps down to 0 after 30 days without a deploy. When
that run fails, GitHub notifies only the user who last changed the `cron` line in
the workflow.

To roll back, list the releases with `gigalixir releases` and run
`gigalixir releases:rollback` (the previous release, or `-r <version>`).

Production needs these environment variables:

| Variable          | Purpose                                                                  |
| ----------------- | ------------------------------------------------------------------------ |
| `SECRET_KEY_BASE` | Signs and encrypts cookies (generate with `mix phx.gen.secret`)          |
| `PHX_HOST`        | Public hostname; LiveView rejects websocket connections from other hosts |
| `PHX_SERVER`      | Starts the HTTP server when the release boots                            |
