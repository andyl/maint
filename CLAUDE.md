# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Maint is an extensible Elixir maintenance automation framework. Developers define "chores" (maintenance tasks) as modules implementing the `Maint.Chore` behavior, configure them via `config.exs`, and run them through Mix tasks. The project includes LLM integration via Jido/JidoAI/ReqLLM for an intelligent chat interface.

**Status:** Early-stage — scaffolding and planning are in place, core implementation is pending.

## Build & Test Commands

```bash
mix deps.get          # Install dependencies
mix compile           # Compile the project
mix test              # Run all tests
mix test path/to/test.exs:123  # Run a single test at a specific line
mix format            # Format code
mix format --check-formatted  # Check formatting without changing files
```

### Documentation Lookup (via usage_rules)

```bash
mix usage_rules.docs Enum.zip        # Look up module/function docs
mix usage_rules.search_docs "query"  # Search docs across all deps
mix usage_rules.search_docs "query" -p req  # Search docs for a specific package
```

## Architecture

### Chore System (core concept)

Chores are maintenance task modules in the `Maint.Chore` namespace that implement the `Maint.Chore` behavior with three callbacks: `run/1`, `health/0`, `setup/0`. Chores can live in any application installed as a mix.exs dependency.

A chore has two states:
- **Installed** — the module is present (loaded as a dependency)
- **Configured** — the module is registered in `config.exs` with name, module, and options

Configuration format: `config :maint, chores: [%{name: "...", module: ..., opts: %{}}]`

### Planned Mix Tasks (phased rollout)

| Phase | Task | Purpose |
|-------|------|---------|
| 1 | `mix maint.ls` | List chores |
| 1 | `mix maint.add` | Install/configure chores (uses Igniter) |
| 1 | `mix maint.rm` | Remove chores |
| 1 | `mix maint.run` | Execute a chore |
| 2 | `mix maint.health` | Check system and chore health |
| 2 | `mix maint.setup` | Auto-fix missing requirements |
| 3 | `mix maint.chat` | LLM agent interface (Jido + JidoAI + ReqLLM) |
| 4 | `mix maint.dash` | TUI dashboard |

### Key Dependencies

- **igniter** — code generation and project patching (auto-generates mix.exs/config.exs changes)
- **jido / jido_ai / req_llm** — LLM agent framework for the chat interface
- **usage_rules** — dev tool for looking up dependency docs and usage patterns

### Module Naming Conventions

- Chore modules: `Maint.Chore.*` (follows the `Mix.Tasks.*` pattern)
- Mix task modules: `Mix.Tasks.Maint.*`

## Elixir Conventions (from RULES.md)

- Use `{:ok, result}` / `{:error, reason}` tuples; avoid exceptions for control flow
- Use `with` for chaining failable operations
- Prefer pattern matching on function heads over `if`/`case` in bodies
- Predicate functions: `thing?` not `is_thing` (reserve `is_` for guards)
- Prepend to lists: `[new | list]` not `list ++ [new]`
- Use structs when shape is known; keyword lists for options; maps for dynamic data
- No global config — all configuration is project-local via `config.exs`
- Linux/macOS only; Windows support is out of scope

## Planning Documents

Design decisions and rationale are documented in `plans/1-PlanningSessionOne.md` and `plans/2-PlanningSessionTwo.md`. Consult these before making architectural changes.
