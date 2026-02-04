# Usage Method Analysis: Global and System-Wide Invocation Strategies for Maint

## 1. Overview

Maint currently assumes it is added as a project dependency in `mix.exs`. This
works well for projects that opt in, but creates friction for a common use case:
running maintenance chores against a third-party repository without modifying its
`mix.exs` or `config.exs`. A developer who maintains dozens of Elixir projects
should not need to add `:maint` to each one before checking for outdated
dependencies or running a health sweep.

This document analyzes five methods for invoking Maint — from project-local to
fully global — and recommends a hybrid approach that preserves the existing
project-dep model while enabling system-wide usage.

## 2. Quick Comparison

| Criteria                     | Project Dep (status quo) | Escript            | Mix Archive            | Standalone Project (`~/.config/maint/`) | Mix.install Script     |
|------------------------------|--------------------------|--------------------|------------------------|-----------------------------------------|------------------------|
| Installation effort          | `mix deps.get`           | `mix escript.build && cp` | `mix archive.install`  | Clone/scaffold + `mix deps.get`         | None (just run)        |
| Chore discovery              | Full (compiled modules)  | Frozen at build    | Limited (archive only) | Full (own VM)                           | Full (per-invocation)  |
| Runtime dep resolution       | Mix handles it           | Baked in           | Shares host project    | Independent                             | Mix.install handles it |
| Config extensibility         | `config.exs`             | Compile-time only  | None (no config)       | Own `config.exs`                        | Inline only            |
| Igniter compatibility        | Full                     | None               | Conflict risk          | Full (own project)                      | None                   |
| Jido/JidoAI/ReqLLM compat   | Full                     | Partial (no plugins)| Conflict risk         | Full (own project)                      | Full but slow          |
| Access to host project code  | Full (same VM)           | None               | Full (same VM)         | None (separate VM)                      | None                   |
| Startup overhead             | None (already loaded)    | Low                | Low                    | ~2-5s (mix startup)                     | High (compile + cache) |
| Updatability                 | `mix deps.update`        | Rebuild + copy     | `mix archive.install`  | `mix deps.update` in standalone         | Always latest (or cached) |
| Offline capable              | Yes                      | Yes                | Yes                    | Yes                                     | No (first run)         |

## 3. Detailed Analysis

### Method 1: Project Dependency (Status Quo)

The current model. Maint is listed in `mix.exs` `deps`, configured in
`config.exs`, and invoked via `mix maint.*` tasks.

**Strengths:**
- Full access to the host project's compiled modules, enabling chores like
  `ProjectInfo` to introspect the codebase
- Standard Elixir dependency management — versioning, updates, and lock files
  work as expected
- Igniter integration works natively (`mix igniter.install maint`)
- Config merging follows Elixir conventions
- Chore discovery via `module_info(:attributes)` works across all loaded
  applications

**Fundamental limitation:** Maint must be added to every project that wants to
use it. For a developer maintaining 30 projects, this means 30 `mix.exs`
changes, 30 lock file updates, and ongoing version management across all of
them. This is the problem the remaining methods attempt to solve.

### Method 2: Escript

Build Maint into a standalone executable via `mix escript.build`.

**How it works:** Compiles all dependencies into a single `.beam`-bundled binary.
Invoked as `./maint run deps_outdated` or installed to `PATH`.

**Why it's a poor fit:**
- Dependencies are frozen at build time — no runtime extensibility, no adding
  third-party chore packages after the fact
- No access to host project's compiled modules (runs in its own VM without the
  project's code loaded)
- No `config.exs` integration — configuration must be done via CLI flags or
  environment variables
- Igniter cannot operate (it needs Mix project context)
- Jido/JidoAI work but cannot discover project-local chore modules
- Updating requires rebuilding the escript

**Verdict:** Escripts solve distribution but sacrifice everything that makes Maint
useful. Not recommended.

### Method 3: Mix Archive

Package Maint as a Mix archive (`.ez` file) installed globally via
`mix archive.install`.

**How it works:** Archives are loaded into every Mix invocation. Mix tasks defined
in the archive are available in any project, similar to how `phx_new` is
distributed as an archive.

**The dep conflict problem:** Maint's dependency tree is heavy — igniter, jido,
jido_ai, and req_llm each bring substantial transitive dependencies. If any host
project uses a different version of these libraries, the archive's versions
conflict with the project's versions in the same VM. This is the exact problem
that bit `phoenix_new` before it was slimmed down to near-zero dependencies.

**What a lightweight archive could do:**
- Provide `mix maint.*` task entry points that detect and delegate
- If the host project has `:maint` in its deps, delegate to the project-local
  version (already loaded)
- If not, delegate to a standalone installation (Method 4)
- Carry no heavy dependencies — just the dispatcher logic

**Verdict:** Viable only as a thin dispatcher. Must not bundle igniter, jido,
or req_llm. This insight shapes the recommended approach below.

### Method 4: Standalone Mix Project (`~/.config/maint/`)

Maintain a full Maint installation as a standalone Mix project in the user's
home directory.

**How it works:**
- A Mix project lives at `~/.config/maint/` with its own `mix.exs`, `config/`,
  and `lib/` directories
- The project includes `:maint` and any additional chore packages as
  dependencies
- Invoked via `cd ~/.config/maint && mix maint.run <chore>` or wrapped in a
  shell alias / dispatcher script
- Configuration lives at `~/.config/maint/config/config.exs`

**Strengths:**
- Full dependency resolution — igniter, jido, req_llm all work without conflict
- Extensible — users can add chore packages to the standalone project's
  `mix.exs`
- Own `config.exs` for global chore configuration
- Updateable via standard `mix deps.update maint`

**The two-VM problem:** The standalone project runs in its own BEAM VM. It
cannot access the host project's compiled modules. Chores that need to
introspect the target project's code (e.g., listing modules, analyzing
supervision trees) cannot work from the standalone VM.

Workarounds exist but add complexity:
- Shell out to `mix run -e "..."` in the target project directory
- Use `Code.compile_file/1` to load specific files (fragile, no deps)
- Accept that some chores are project-local only

**Invocation complexity:** Running `cd ~/.config/maint && mix maint.run
--target /path/to/project deps_outdated` is verbose. This is where the archive
dispatcher (Method 3) helps — it provides the `mix maint.*` entry point and
handles delegation.

**Verdict:** Best option for global chore execution. The two-VM limitation is
real but acceptable — many useful chores (dependency checks, github integration,
CI health) don't need compiled-module access.

### Method 5: Elixir Script with Mix.install

Use `Mix.install/2` in a standalone `.exs` script to pull Maint and its
dependencies on demand.

**How it works:**
```elixir
# ~/.local/bin/maint.exs
Mix.install([
  {:maint, "~> 0.1"},
  {:some_chore_package, "~> 1.0"}
])

Maint.run(System.argv())
```

**Strengths:**
- Zero installation friction — just run `elixir maint.exs run deps_outdated`
- Always gets the latest version (or uses Mix.install's cache)
- Good for demos, one-off usage, and trying Maint without commitment

**Why it's poor for production tooling:**
- First run compiles all dependencies from scratch (~30-60 seconds for Maint's
  dep tree)
- Cache is keyed on the exact dependency specification — any version bump
  triggers full recompilation
- No `config.exs` support — configuration must be inline or via env vars
- No Igniter compatibility (no Mix project context)
- Cannot be extended after the script is written without editing the script
- The same two-VM limitation as Method 4

**Verdict:** Useful for demos and first-time exploration. Not suitable as a
primary invocation method.

## 4. Recommended Approach: 3-Tier Hybrid

The analysis points to a layered strategy where each tier serves a different use
case. No single method covers all needs.

### Tier 1: Project Dependency (unchanged, primary)

The existing model remains the recommended way to use Maint. When Maint is a
project dependency, all features work — chore discovery, Igniter integration,
LLM chat, compiled-module introspection.

**No changes needed.** This is what gets built first and what the documentation
leads with.

### Tier 2: Minimal Mix Archive (dispatcher)

A lightweight Mix archive that provides `mix maint.*` task entry points globally.
The archive contains no heavy dependencies — only dispatcher logic.

**Behavior:**
1. Check if the current Mix project has `:maint` in its dependencies
2. If yes: delegate to the project-local Maint (already loaded in the VM) —
   this is a no-op passthrough
3. If no: delegate to the Tier 3 standalone installation by spawning
   `mix maint.*` in the `~/.config/maint/` project directory, passing
   `--target #{File.cwd!()}` to identify the host project

**What the archive contains:**
- `Mix.Tasks.Maint.*` modules (thin shells that detect and delegate)
- No runtime dependencies beyond Elixir stdlib

**What the archive does NOT contain:**
- igniter, jido, jido_ai, req_llm, or any other heavy dependency
- Any chore implementation
- Any configuration system

### Tier 3: Standalone Project (`~/.config/maint/`)

A scaffolded Mix project that serves as the global Maint installation.

**Scaffolding:** Created via `mix maint.init` (provided by the Tier 2 archive)
or manual setup. The init task generates:

```
~/.config/maint/
├── mix.exs            # {:maint, "~> 0.1"} + user's chore packages
├── config/
│   └── config.exs     # Global chore configuration
└── lib/
    └── .gitkeep
```

**Usage pattern:**
- The Tier 2 archive detects the absence of project-local Maint and shells out
  to the standalone project
- Users can add chore packages to `~/.config/maint/mix.exs`
- Global configuration lives in `~/.config/maint/config/config.exs`

## 5. Config Merge Strategy

When Maint runs, configuration is resolved in priority order (highest wins):

1. **CLI flags** — `--chore-opt key=value`, `--target /path`
2. **Project `.maint.exs`** — optional file in the project root for
   project-specific Maint settings that don't belong in `config.exs` (e.g.,
   when Maint is not a project dependency but the user wants project-specific
   overrides)
3. **Project `config.exs`** — standard `config :maint, ...` (only when Maint
   is a project dependency)
4. **Global `~/.config/maint/config/config.exs`** — defaults for all projects

This ordering means project-level settings always override global defaults, and
CLI flags override everything. The `.maint.exs` file provides a way for
non-Maint projects to carry Maint configuration without adding Maint as a
dependency.

## 6. Impact on Existing Code

### `Maint` module
- Add a `config/0` function that implements the merge strategy above
- Current `Application.get_env(:maint, :chores)` calls should route through
  this function

### Mix tasks (`Mix.Tasks.Maint.*`)
- Add a `--target` flag to all tasks, specifying the directory to operate on
  (defaults to `File.cwd!()`)
- Tasks must handle the case where `--target` points to a directory that is not
  the current Mix project

### Igniter workflow
- Igniter operations (e.g., `maint.add` modifying `mix.exs`) must respect
  `--target` — they should operate on the target project's files, not the
  standalone project's files
- When running from Tier 3, Igniter operations targeting the host project
  require careful working-directory management

### New tasks
- `mix maint.init` — scaffolds the `~/.config/maint/` standalone project
  (provided by the archive or by Maint itself)

## 7. Implementation Sequencing

The tiers should be built in order, each building on the previous:

**Phase A: Finish Tier 1 (project dependency)**
- Complete the Phase 1 Mix tasks (`maint.ls`, `maint.add`, `maint.rm`,
  `maint.run`) as planned
- All development and testing assumes Maint is a project dependency
- This is the current work and should not be delayed by global invocation
  concerns

**Phase B: Add `--target` flag**
- Add `--target <dir>` to all Mix tasks
- Implement the config merge strategy (CLI > `.maint.exs` > `config.exs` >
  global)
- This is a prerequisite for Tiers 2 and 3 and is independently useful
  (running maint against a subdirectory or monorepo package)

**Phase C: Build the Mix archive dispatcher**
- Create a separate Mix project (e.g., `maint_archive`) that builds the `.ez`
  file
- Implement detection logic: project-local Maint present? → passthrough.
  Otherwise → delegate to standalone
- Publish to Hex as a separate package so users can `mix archive.install hex
  maint_archive`

**Phase D: Scaffold the standalone project**
- Implement `mix maint.init` to generate `~/.config/maint/`
- Document the standalone setup in the README
- Test the full flow: archive detects no local Maint → spawns standalone →
  standalone runs chore with `--target`

## 8. Open Questions

### Separate Hex packages?
Should the archive dispatcher be a separate Hex package (`maint_archive`) or
part of the main `maint` package with a separate build target? A separate
package is cleaner (different deps, different versioning) but adds maintenance
overhead.

### Compiled-module access in Tier 3
Chores running in the standalone VM cannot call into the host project's modules.
Is there a viable workaround beyond shelling out? Potential approaches:
- `Code.compile_file/1` on specific files (fragile, ignores deps)
- Starting a hidden node in the host project and connecting via distribution
  (heavy, requires the host project to be running)
- Accepting the limitation and documenting which chores require project-local
  installation

### `.maint.exs` format
What should `.maint.exs` contain? Options:
- Pure Elixir keyword list (like `mix.exs`)
- `Config`-style macros (like `config.exs`)
- A simple map evaluated with `Code.eval_file/1`

The simplest option is a keyword list evaluated with `Code.eval_file/1`, but
this means no `import Config` syntax.

### Subprocess overhead for chat
The `mix maint.chat` task starts an interactive LLM session. If invoked through
the Tier 2 → Tier 3 delegation path, the subprocess model adds latency and
complicates stdio handling. Should chat always require project-local
installation, or can the archive detect chat mode and exec (replacing its
process) into the standalone project?

### Revisiting "drop global config"
Planning Session Two decided to drop global config. This analysis does not
reverse that decision — project-local config via `config.exs` remains the
primary configuration mechanism. What this adds is a global *installation*
mechanism: a way to have Maint available system-wide without per-project
dependency changes. The global `~/.config/maint/config/config.exs` is
configuration for the standalone installation itself, not a global override
for project-local settings.
