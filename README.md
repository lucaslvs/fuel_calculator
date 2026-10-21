# FuelCalculator

[![CI](https://github.com/lucaslvs/fuel_calculator/actions/workflows/ci.yml/badge.svg)](https://github.com/lucaslvs/fuel_calculator/actions/workflows/ci.yml)
[![Coverage](https://img.shields.io/endpoint?url=https://gist.githubusercontent.com/lucaslvs/92a585ac99ba97b6bca7818f6e6da8f9/raw/fuel_calculator-coverage.json)](https://github.com/lucaslvs/fuel_calculator/actions/workflows/ci.yml)

A Phoenix LiveView application that calculates the fuel required for interplanetary
flight paths (launches and landings on Earth, Moon and Mars).

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
