# FuelCalculator

[![CI](https://github.com/lucaslvs/fuel_calculator/actions/workflows/ci.yml/badge.svg)](https://github.com/lucaslvs/fuel_calculator/actions/workflows/ci.yml)
[![Deploy](https://img.shields.io/endpoint?url=https://gist.githubusercontent.com/lucaslvs/92a585ac99ba97b6bca7818f6e6da8f9/raw/fuel_calculator-deploy.json)](https://fuel-calculator.gigalixirapp.com)
[![Coverage](https://img.shields.io/endpoint?url=https://gist.githubusercontent.com/lucaslvs/92a585ac99ba97b6bca7818f6e6da8f9/raw/fuel_calculator-coverage.json)](https://github.com/lucaslvs/fuel_calculator/actions/workflows/ci.yml)

A Phoenix LiveView application that calculates the fuel required for interplanetary
flight paths (launches and landings on Earth, Moon and Mars).

Live demo: <https://fuel-calculator.gigalixirapp.com> (hosted on Gigalixir's free
tier, deployed automatically from `main` after CI passes).

See [`docs/CHALLENGE.md`](docs/CHALLENGE.md) for the full challenge description.

## Requirements

- Erlang/OTP 29.1.2 and Elixir 1.20.4 (pinned in `.tool-versions`; works with
  [mise](https://mise.jdx.dev) or [asdf](https://asdf-vm.com))
- No database required

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

The same checks run on every push via GitHub Actions, and the build fails below
90% coverage. The workflow also publishes a per-module coverage summary, updates
the coverage badge, lints itself with [actionlint](https://github.com/rhysd/actionlint)
and fails when a Hex dependency is retired or has a security advisory
(`mix hex.audit`).

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

Changes that only touch documentation (`*.md`, `docs/`) skip CI and deployment.
The same job also redeploys `main` on the 1st and 15th of each month, because
Gigalixir's free tier scales apps down to 0 after 30 days without a deploy. That
run skips the deploy if `main` has moved since it started, and when it fails,
GitHub notifies only the user who last changed the `cron` line in the workflow.

To roll back, list the releases with `gigalixir releases` and run
`gigalixir releases:rollback` (the previous release, or `-r <version>`).

Production needs these environment variables:

| Variable          | Purpose                                                                  |
| ----------------- | ------------------------------------------------------------------------ |
| `SECRET_KEY_BASE` | Signs and encrypts cookies (generate with `mix phx.gen.secret`)          |
| `PHX_HOST`        | Public hostname; LiveView rejects websocket connections from other hosts |
| `PHX_SERVER`      | Starts the HTTP server when the release boots                            |
