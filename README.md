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
mix precommit     # compile --warnings-as-errors, format, credo --strict, test
mix test --cover  # test coverage (90% threshold, HTML report in cover/)
mix dialyzer      # static type analysis
```

The same checks run on every push via GitHub Actions, which also publishes a
per-module coverage summary and updates the coverage badge.
The CI workflow also lints itself with [actionlint](https://github.com/rhysd/actionlint).

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

Production needs these environment variables:

| Variable          | Purpose                                                                  |
| ----------------- | ------------------------------------------------------------------------ |
| `SECRET_KEY_BASE` | Signs and encrypts cookies (generate with `mix phx.gen.secret`)          |
| `PHX_HOST`        | Public hostname; LiveView rejects websocket connections from other hosts |
| `PHX_SERVER`      | Starts the HTTP server when the release boots                            |
