# Maint — Product Requirements Document (Phases 1–3)

## Overview

Maint is an extensible Elixir maintenance automation framework. Developers define
"chores" as modules implementing the `Maint.Chore` behaviour, register them in
`config.exs`, and invoke them via Mix tasks.

## Target Users

Elixir developers who want a standardized, extensible way to run project
maintenance tasks (dependency checks, code hygiene, project health) from the CLI.

## Platform

Linux and macOS only. No Windows support.

## Core Concepts

### Chore

A module in the `Maint.Chore.*` namespace implementing the `Maint.Chore`
behaviour. Three callbacks:

- `run(opts)` — Execute the chore. Receives config opts merged with CLI args.
  Returns `{:ok, result} | {:error, reason}`.
- `health()` — Introspect requirements (API keys, tools, deps).
  Returns `{:ok, [check_results]} | {:error, [issues]}`.
- `setup()` — Auto-fix missing requirements.
  Returns `:ok | {:error, reason}`.

### Chore States

- **Installed** — module is present as a mix.exs dependency
- **Configured** — module is registered in `config.exs`

### Configuration Format

Keyword lists in `config.exs`:

```elixir
config :maint,
  chores: [
    [name: :deps_outdated, module: Maint.Chore.DepsOutdated, opts: []],
    [name: :project_info, module: Maint.Chore.ProjectInfo, opts: []]
  ]
```

### Persistence

config.exs only. `maint.add` and `maint.rm` use Igniter to edit config.exs
programmatically.

## Mix Tasks

### Phase 1 — Core CLI

| Task | Description |
|------|-------------|
| `mix maint.ls` | List chores. Default: configured only. `--all` flag shows installed-but-unconfigured chores too. |
| `mix maint.add` | Two modes: **install** (`--install hex_package`) uses Igniter to add mix.exs dep + config.exs entry; **configure** (`--configure ModuleName`) only edits config.exs for already-installed chore modules. |
| `mix maint.rm` | Remove a chore's config.exs entry by name. `--uninstall` flag also removes the mix.exs dependency via Igniter. |
| `mix maint.run <name>` | Run a configured chore. Merges config opts with CLI flags, calls `run/1`. |

### Phase 2 — Health & Setup

| Task | Description |
|------|-------------|
| `mix maint.health` | Run `health/0` on all configured chores (or a named chore). Report missing requirements. |
| `mix maint.setup` | Run `setup/0` on all configured chores (or a named chore). Auto-fix what's possible, print manual instructions for the rest. |

## Default Chores (shipped with Maint)

1. **`Maint.Chore.DepsOutdated`** — Checks for outdated Hex dependencies.
2. **`Maint.Chore.ProjectInfo`** — Displays project metadata (app name, version,
   Elixir version, dep count).
3. **`Maint.Chore.DepsUnused`** — Identifies potentially unused dependencies by
   scanning the codebase.

### Phase 3 — LLM Chat Interface

| Task | Description |
|------|-------------|
| `mix maint.chat` | Interactive LLM-powered chat for reasoning across chores. Streaming responses. Tool calling to list, run, health-check, and setup chores. |

#### Chat Configuration

```elixir
config :maint,
  chat: [
    model: "anthropic:claude-sonnet-4-20250514"
  ]
```

Overridable via `--model` CLI flag. Requires an `ANTHROPIC_API_KEY` environment
variable (or other provider key, depending on model string). Keys are loaded
automatically from `.env` via dotenvy/ReqLLM.

#### Chat Tools

The LLM has access to four tools:

- **list_chores** — Returns all configured chores with name, module, and opts.
- **run_chore** — Executes a configured chore by name and returns the result.
- **check_health** — Runs `health/0` on a named chore (or all chores).
- **run_setup** — Runs `setup/0` on a named chore (or all chores).

#### Architecture Decision

Phase 3 builds directly on **ReqLLM** (`Context`, `Tool`, `stream_text`) rather
than the full Jido.AI.Agent stack. ReqLLM provides conversation management, tool
calling, and streaming — everything needed for an interactive CLI chat loop.
Jido/JidoAI remain as dependencies for potential future use (Phase 3.5+ agent
orchestration) but are not used by `maint.chat` itself.

## Out of Scope (Phases 1–3)

- TUI dashboard (Phase 4)
- Scheduling / background jobs
- Global config (~/.config)
- Windows support
