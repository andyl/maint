# Architecture Analysis: Chores vs. Mix Tasks

## The Question

Would it be better for "chores" to be implemented as regular Mix tasks? Is there any advantage to the custom `Maint.Chore` behavior abstraction, or does it add unnecessary ceremony over what Mix already provides?

## What the Chore Abstraction Adds

Five concrete capabilities distinguish chores from plain Mix tasks:

### 1. `health/0` — self-reporting prerequisites

Every chore can report whether its prerequisites are met (API keys present, tools installed, git config correct, etc.). This enables `mix maint.health` to sweep all chores and produce a unified status report. With plain Mix tasks, there is no standard way to ask "are you ready to run?" without actually running the task.

### 2. `setup/0` — auto-repair capability

Chores can auto-fix their own prerequisites. This pairs with `health/0` to create a diagnose-then-repair loop: run `health/0` to identify what is missing, then run `setup/0` to fix what can be fixed automatically. Mix tasks have no equivalent pattern.

### 3. Uniform return contract (`{:ok, result} | {:error, reason}`)

Every callback returns standard ok/error tuples. This is what makes the LLM chat integration (`Maint.Chat.Tools`) work cleanly — the four chat tools (`list_chores`, `run_chore`, `check_health`, `run_setup`) can call any chore and reliably handle the result. Plain Mix tasks return `:ok` or raise exceptions, which is much harder to compose programmatically. Mix tasks that write to stdout and raise on failure are much harder for an LLM to interact with programmatically.

### 4. Configuration layer (installed vs. configured)

The config system in `config.exs` allows chore modules to be available from dependencies but selectively activated per-project with per-project options. A chore has two states:

- **Installed** — the module is loaded as a mix.exs dependency
- **Configured** — the module is registered in `config.exs` with name, module, and opts

Mix tasks are binary: either present or not. You cannot have a Mix task "installed but not activated" with project-specific options.

### 5. Programmatic discovery across all loaded applications

`Maint.installed_chores()` finds all modules implementing the `Maint.Chore` behavior across all loaded Erlang applications via module introspection (`module_info(:attributes)`). This powers both `mix maint.ls --all` and the LLM's `list_chores` tool. While `mix help` discovers Mix tasks, the chore discovery system integrates with the configuration layer (showing what is installed but not configured).

## Where Plain Mix Tasks Would Be Simpler

- **No behavior definition, no config system, no discovery module** — you just create `Mix.Tasks.Maint.DepsOutdated` and you are done. No extra abstractions.
- **`mix help` already discovers and lists Mix tasks** — the discovery mechanism is built into Mix itself.
- **Each task is self-contained with no framework overhead** — no need to implement three callbacks when you only need `run/1`.
- **The existing chores are thin wrappers that do not exercise health/setup** — `ProjectInfo`, `DepsOutdated`, and `DepsUnused` all have stub implementations for `health/0` (returning `{:ok, []}`) and `setup/0` (returning `:ok`). They only meaningfully implement `run/1`, which means the abstraction is currently carrying dead weight.

## Assessment

The chore abstraction earns its keep if and only if health/setup and the LLM integration are actually used.

- **Health/setup are genuine capabilities** that cannot be replicated with Mix task conventions without effectively rebuilding the same abstraction using naming conventions instead of a behavior (e.g., creating separate `mix maint.health.deps_outdated` tasks for each chore).
- **YAGNI risk** — if chores end up only implementing `run/1` with stub health/setup, the abstraction is dead weight and plain Mix tasks would be strictly better. The three existing chores are close to this situation.
- **The strongest single argument for keeping chores is the LLM chat system** — having a uniform, return-value-based contract across all maintenance operations is what makes `ReqLLM.Tool.execute/2` work cleanly. This is the most concrete, immediate justification.

## Decision

Keep the chore system. The health/setup callbacks and the uniform return contract for LLM integration justify the abstraction — but only if those capabilities are exercised. This means:

- Existing chores (`DepsOutdated`, `DepsUnused`, `ProjectInfo`) should get meaningful `health/0` implementations (e.g., `DepsOutdated` could check that Hex is available and the network is reachable).
- Existing chores should get meaningful `setup/0` implementations where applicable.
- Future chores should be designed to leverage all three callbacks, not just `run/1`.
- The LLM integration should be treated as a first-class justification for the architecture, not an afterthought.
