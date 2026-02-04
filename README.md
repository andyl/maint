# Maint

An extensible Elixir maintenance automation framework. Define "chores" as
modules implementing the `Maint.Chore` behaviour, register them in `config.exs`,
and invoke them via Mix tasks — or chat with an LLM that can run them for you.

## Installation

Add `maint` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:maint, "~> 0.1.0"}
  ]
end
```

Then fetch dependencies:

```bash
mix deps.get
```

## Core Concepts

### Chores

A **chore** is a maintenance task module in the `Maint.Chore.*` namespace that
implements the `Maint.Chore` behaviour with three callbacks:

- `run(opts)` — Execute the chore. Returns `{:ok, result} | {:error, reason}`.
- `health()` — Introspect requirements (API keys, tools, deps). Returns `{:ok, [checks]} | {:error, [issues]}`.
- `setup()` — Auto-fix missing requirements. Returns `:ok | {:error, reason}`.

### Chore States

- **Installed** — the chore module is present as a mix.exs dependency
- **Configured** — the chore module is registered in `config.exs`

### Configuration

Chores are configured as keyword lists in `config.exs`:

```elixir
config :maint,
  chores: [
    [name: :deps_outdated, module: Maint.Chore.DepsOutdated, opts: []],
    [name: :project_info, module: Maint.Chore.ProjectInfo, opts: []],
    [name: :deps_unused, module: Maint.Chore.DepsUnused, opts: []]
  ]
```

## Mix Tasks

### `mix maint.ls`

List chores. By default shows only configured chores. Use `--all` to also show
installed-but-unconfigured chore modules.

```bash
mix maint.ls          # configured chores only
mix maint.ls --all    # also show installed but unconfigured
```

### `mix maint.run <name>`

Run a configured chore by name. Config opts are merged with any CLI flags
(CLI takes precedence).

```bash
mix maint.run project_info
mix maint.run deps_outdated
mix maint.run deps_unused
```

### `mix maint.add`

Add a chore to the project. Two modes:

```bash
# Install a hex package and configure it
mix maint.add --install some_hex_package --configure Maint.Chore.SomeChore --name some_chore

# Configure an already-installed chore module
mix maint.add --configure Maint.Chore.DepsOutdated --name deps_outdated
```

Uses [Igniter](https://hex.pm/packages/igniter) to edit `mix.exs` and `config.exs`
programmatically.

### `mix maint.rm <name>`

Remove a chore's config.exs entry by name. Optionally also remove the mix.exs
dependency.

```bash
mix maint.rm deps_unused
mix maint.rm deps_unused --uninstall some_hex_package
```

### `mix maint.health`

Check health of configured chores. Runs `health/0` on all chores or a specific one.

```bash
mix maint.health              # all chores
mix maint.health project_info # one chore
```

### `mix maint.setup`

Run setup for configured chores. Calls `setup/0` to auto-fix missing requirements
and prints manual instructions for anything that can't be auto-fixed.

```bash
mix maint.setup              # all chores
mix maint.setup deps_outdated # one chore
```

### `mix maint.chat`

Start an interactive LLM-powered chat session. The agent can reason across all
your chores, run them, check health, and fix issues — all through natural
language.

```bash
mix maint.chat
mix maint.chat --model anthropic:claude-haiku-4-5
```

Requires an API key for the configured provider (e.g., `ANTHROPIC_API_KEY`
environment variable or `.env` file).

#### Example questions

```
you> What maintenance chores do I have available?
you> Run the project info chore and tell me about this project.
you> Are my dependencies up to date?
you> Check the health of all my chores.
you> Are there any unused dependencies in this project?
you> Run setup for all chores and tell me if anything needs manual attention.
you> What Elixir version am I running?
you> Which of my dependencies are the most out of date?
```

#### Chat configuration

Set the default model in `config.exs`:

```elixir
config :maint,
  chat: [
    model: "anthropic:claude-sonnet-4-20250514"
  ]
```

Override at runtime with `--model`.

## Default Chores

Maint ships with three built-in chores:

| Chore | Description |
|-------|-------------|
| `Maint.Chore.DepsOutdated` | Checks for outdated Hex dependencies (wraps `mix hex.outdated`) |
| `Maint.Chore.ProjectInfo` | Displays project metadata — app name, version, Elixir/OTP versions, dep count |
| `Maint.Chore.DepsUnused` | Identifies potentially unused dependencies by scanning `lib/` source files |

## Writing a Custom Chore

```elixir
defmodule Maint.Chore.MyChore do
  @behaviour Maint.Chore

  @impl true
  def run(opts) do
    # Your maintenance logic here
    {:ok, "All good!"}
  end

  @impl true
  def health do
    # Check that requirements are met
    {:ok, []}
  end

  @impl true
  def setup do
    # Auto-fix missing requirements, or return {:error, reason}
    :ok
  end
end
```

Then add it to your config:

```elixir
config :maint,
  chores: [
    [name: :my_chore, module: Maint.Chore.MyChore, opts: []]
  ]
```

## Platform

Linux and macOS only. Windows is not supported.

## License

MIT
