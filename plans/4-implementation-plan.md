# Maint — Implementation Plan (Phases 1–3)

## Step 1: Project Foundation

### Create `config/config.exs`

```elixir
import Config
config :maint, chores: []
```

### Create `lib/maint/chore.ex` — Behaviour Definition

```elixir
defmodule Maint.Chore do
  @callback run(opts :: keyword()) :: {:ok, term()} | {:error, term()}
  @callback health() :: {:ok, list()} | {:error, list()}
  @callback setup() :: :ok | {:error, term()}
end
```

### Rewrite `lib/maint.ex` — Core Module

Replace the placeholder with:
- `Maint.configured_chores/0` — reads chore list from
  `Application.get_env(:maint, :chores, [])`
- `Maint.find_chore/1` — looks up a chore by name from config
- `Maint.installed_chores/0` — discovers modules implementing `Maint.Chore`
  behaviour across loaded applications

## Step 2: `mix maint.ls`

**File:** `lib/mix/tasks/maint.ls.ex`

- Parse `--all` flag via `OptionParser`
- Default: show only configured chores (from config)
- With `--all`: also discover installed-but-unconfigured chore modules
- Output as a formatted table: name, module, status (configured/installed)

## Step 3: `mix maint.run`

**File:** `lib/mix/tasks/maint.run.ex`

- Takes chore name as first positional arg
- Remaining args parsed as CLI opts via `OptionParser` (accepts any switch)
- Looks up chore via `Maint.find_chore/1`
- Merges config opts with CLI opts (CLI takes precedence)
- Calls `module.run(merged_opts)`
- Prints result or error

## Step 4: `mix maint.add`

**File:** `lib/mix/tasks/maint.add.ex`

Two modes controlled by flags:
- `mix maint.add --install <hex_package>` — Uses `Igniter.Project.Deps` to add
  dep to mix.exs, then prompts to configure
- `mix maint.add --configure <module_name> --name <chore_name>` — Uses
  `Igniter.Project.Config` to add chore entry to config.exs
- Validates that the module exists and implements `Maint.Chore` behaviour before
  configuring

## Step 5: `mix maint.rm`

**File:** `lib/mix/tasks/maint.rm.ex`

- Takes chore name as arg
- Uses `Igniter.Project.Config` to remove the chore entry from config.exs
- `--uninstall` flag: also removes the mix.exs dependency via
  `Igniter.Project.Deps`

## Step 6: Default Chores

### `lib/maint/chore/deps_outdated.ex`

- Runs `mix hex.outdated` or uses Hex API to check for outdated deps
- `health/0` checks that Hex is available
- `setup/0` no-op (Hex comes with Elixir)

### `lib/maint/chore/project_info.ex`

- Reads `Mix.Project.config()` and formats output (app, version, elixir version,
  dep count, etc.)
- `health/0` and `setup/0` are no-ops

### `lib/maint/chore/deps_unused.ex`

- Cross-references mix.exs deps with actual module usage in `lib/`
- `health/0` and `setup/0` are no-ops

## Step 7: `mix maint.health` (Phase 2)

**File:** `lib/mix/tasks/maint.health.ex`

- No args: run `health/0` on all configured chores
- With chore name arg: run on just that chore
- Collect and display results in a summary table (chore name, status, issues)

## Step 8: `mix maint.setup` (Phase 2)

**File:** `lib/mix/tasks/maint.setup.ex`

- Same arg pattern as health
- Calls `setup/0` on chores
- Displays what was auto-fixed and what requires manual action

## Step 9: `mix maint.chat` (Phase 3)

### Chat tools module: `lib/maint/chat/tools.ex`

Defines the four ReqLLM tools that the LLM can call:

- `list_chores` — Calls `Maint.configured_chores/0`, formats as text.
- `run_chore` — Takes `chore_name` param, calls `Maint.find_chore/1` then
  `module.run/1`.
- `check_health` — Takes optional `chore_name` param. Runs `health/0` on one
  or all configured chores.
- `run_setup` — Takes optional `chore_name` param. Runs `setup/0` on one or
  all configured chores.

Each tool callback returns `{:ok, string}` for the LLM to consume.

### Chat loop module: `lib/maint/chat.ex`

Core conversation loop built on ReqLLM:

- `Maint.Chat.run/1` — Entry point. Accepts opts (model, system prompt).
- Maintains a `ReqLLM.Context` with system prompt + conversation history.
- Uses `ReqLLM.stream_text/3` for real-time token streaming to stdout.
- After each assistant response, checks for tool calls in the streamed chunks.
- When tool calls are present: executes them via `ReqLLM.Tool.execute/2`,
  appends tool result messages to context, then makes a follow-up
  `stream_text` call for the final response.
- Recursive loop: read user input → stream response → handle tools → repeat.
- Exits on "exit", "quit", or Ctrl-D (EOF).

System prompt includes:
- Description of Maint framework and available tools
- Instruction to use tools rather than guessing
- Brief summary of configured chores

### Mix task: `lib/mix/tasks/maint.chat.ex`

- Parses `--model` flag via `OptionParser`
- Reads default model from `Application.get_env(:maint, :chat, [])[:model]`
  or falls back to `"anthropic:claude-sonnet-4-20250514"`
- Calls `Maint.Chat.run(model: model)`

### Configuration

Add to `config/config.exs`:

```elixir
config :maint,
  chat: [
    model: "anthropic:claude-sonnet-4-20250514"
  ]
```

### Tests

| File | Tests |
|------|-------|
| `test/maint/chat/tools_test.exs` | Tool callback functions return expected formats |
| `test/mix/tasks/maint_chat_test.exs` | Task module exists and has run/1 |

Note: The interactive chat loop and streaming are difficult to unit test.
Tests focus on the tool callbacks (pure functions) and basic task wiring.

## Step 10: Tests

### Test support

- `test/support/test_chore.ex` — A mock chore implementing `Maint.Chore` for
  use across tests
- Update `test/test_helper.exs` to compile test support files

### Test files

| File | Tests |
|------|-------|
| `test/maint_test.exs` | Core functions: `configured_chores/0`, `find_chore/1`, `installed_chores/0` |
| `test/maint/chore_test.exs` | Behaviour compliance helpers |
| `test/mix/tasks/maint_ls_test.exs` | ls output with/without `--all` |
| `test/mix/tasks/maint_run_test.exs` | run with mock chore, CLI arg merging |
| `test/maint/chore/deps_outdated_test.exs` | Default chore tests |
| `test/maint/chore/project_info_test.exs` | Default chore tests |
| `test/maint/chore/deps_unused_test.exs` | Default chore tests |

## File Summary

| File | Purpose |
|------|---------|
| `config/config.exs` | App config with chores list |
| `lib/maint.ex` | Core module: config reading, chore lookup, discovery |
| `lib/maint/chore.ex` | Behaviour definition |
| `lib/maint/chore/deps_outdated.ex` | Default chore |
| `lib/maint/chore/project_info.ex` | Default chore |
| `lib/maint/chore/deps_unused.ex` | Default chore |
| `lib/mix/tasks/maint.ls.ex` | Mix task |
| `lib/mix/tasks/maint.run.ex` | Mix task |
| `lib/mix/tasks/maint.add.ex` | Mix task (uses Igniter) |
| `lib/mix/tasks/maint.rm.ex` | Mix task (uses Igniter) |
| `lib/mix/tasks/maint.health.ex` | Mix task (Phase 2) |
| `lib/mix/tasks/maint.setup.ex` | Mix task (Phase 2) |
| `lib/maint/chat.ex` | Chat conversation loop (Phase 3) |
| `lib/maint/chat/tools.ex` | Chat tool definitions (Phase 3) |
| `lib/mix/tasks/maint.chat.ex` | Mix task (Phase 3) |
| `test/support/test_chore.ex` | Test helper |

## Verification

1. `mix compile` — compiles cleanly with no warnings
2. `mix test` — all tests pass
3. `mix format --check-formatted` — no formatting issues
4. Manual smoke test:
   - `mix maint.ls` shows default chores
   - `mix maint.run project_info` prints project metadata
   - `mix maint.run deps_outdated` lists outdated deps
   - `mix maint.health` reports health for all chores
   - `mix maint.chat` starts interactive LLM chat (requires API key)
