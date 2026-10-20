# FuelCalculator

[![CI](https://github.com/lucaslvs/fuel_calculator/actions/workflows/ci.yml/badge.svg)](https://github.com/lucaslvs/fuel_calculator/actions/workflows/ci.yml)

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
mix precommit   # compile --warnings-as-errors, format, credo --strict, test
mix dialyzer    # static type analysis
```

The same checks run on every push via GitHub Actions.
