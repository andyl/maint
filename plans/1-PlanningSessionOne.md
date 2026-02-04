# Maint App - Planning Session One

Raw thoughts about a potential maintenance application...

## Query 

I would like to build an elixir app that performs a list of maintenance chores.
I want the list of maintenance chores to be extensible by developers in the
field. The chores would be invoked as Mix tasks. I am thinking of the following
set of mix tasks: mix maint.run <chore_name>, mix maint.list, mix maint.add
<chore spec>, mix maint.rm <chore_name>. The system would require configuration
(config.exs) to specify <chore_name>, <chore_module> and optionally
<chore_options>. Also possibly there could be a global config in
~/.config/maint/conf.yaml. Please critique my choice of name (chore) - should I
use 'job' or some other term instead of chore? Also please critique my overall
concept. Should I use another approach? My goals: provide a decent library of
default chores, let the cores by extensible in the field, and let others write
their own chore libraries. I would like to incorporate to the extent possible
modern LLM techniques (like skills). My thinking is that each chore could make
calls to an LLM using ReqLLM. Please analyze this concept, identify flaws and
if possible define a better approach than the one I have described.

## Response 

### Critique of Terminology: "Chore" vs. Alternatives

Your choice of "chore" as the term for these maintenance operations is
reasonable—it's evocative of routine, low-glamour work like housekeeping, which
fits maintenance tasks well. It's also concise and unlikely to clash with
Elixir ecosystem terms. However, let's weigh it against alternatives:

- **Job**: This is a common term in Elixir (e.g., in libraries like Oban for
  background jobs or Exq for Redis-based queuing). It might cause confusion if
  your system ever integrates with such tools, as "job" often implies
  asynchronous, queued execution rather than direct invocation via Mix tasks.
  If your chores could evolve into background processes, "job" might be a
  better fit for future-proofing, but it risks semantic overlap.

- **Task**: This directly conflicts with Mix's own "task" concept (e.g.,
  `Mix.Task`). Using it could lead to developer confusion when discussing "Mix
  tasks" vs. your "maintenance tasks." Avoid this.

- **Operation** (or "Op"): Shorter and neutral, often used in ops/devops
  contexts (e.g., "ops tasks"). It emphasizes action without implying duration
  or complexity.

- **Routine**: Similar to "chore" but sounds more programmatic and less
  domestic. It aligns with "maintenance routines."

- **Command**: Too generic, as it overlaps with CLI commands in general.

**Recommendation**: Stick with "chore" if you like the flavor—it stands out and
isn't overloaded in Elixir. If you want something more professional or
scalable, switch to "job" but scope it clearly (e.g., "maintenance job") to
differentiate from background job systems. Ultimately, the name is less
critical than consistency; document it well in your README and module docs.

### Critique of Overall Concept

Your concept is solid for a extensible maintenance framework in Elixir: using
Mix tasks for invocation keeps it idiomatic and developer-friendly, as Mix is
the standard for CLI tooling in Elixir projects. The commands (`maint.run`,
`maint.list`, `maint.add`, `maint.rm`) form a coherent API, reminiscent of
package managers or config tools. Configuration via `config.exs` leverages
Elixir's built-in config system, which handles environment-specific settings
nicely (e.g., via `Config` module).

Strengths:
- **Extensibility**: Allowing field developers to add chores via config or
  commands supports your goal of on-site customization without forking the core
  app.
- **Defaults and Libraries**: Providing a "decent library" of default chores is
  great; others can publish their own as Hex packages (e.g., `my_chore_lib`
  with pre-defined chore modules).
- **Simplicity**: Mix tasks are easy to implement (via `Mix.Task` behaviour)
  and integrate with tools like releases (e.g., via Distillery or Elixir
  releases).

Flaws and Potential Issues:
1. **Persistence and Dynamic Addition/Removal**:
   - `maint.add <chore spec>` and `maint.rm <chore_name>` imply runtime or
     persistent changes, but `config.exs` is compile-time (or runtime-loaded
     but not easily mutable). How does `<chore spec>` work? If it's just a
     string like "name:MyChore,module:MyApp.MyChoreModule,opts:%{foo: bar}",
     where is it stored? Modifying `config.exs` programmatically is brittle
     (file I/O in prod is risky, version control issues).
   - Global `~/.config/maint/conf.yaml` adds complexity: YAML parsing isn't
     native to Elixir (need `yamerl` or similar), and mixing Elixir config with
     external YAML could lead to inconsistencies (e.g., env-specific
     overrides). It also assumes a user-home setup, which doesn't fit
     containerized/Docker deployments.
   - Flaw: This could lead to state drift (e.g., added chores not surviving
     restarts) or security issues (arbitrary module loading from user input).

2. **Security and Validation**:
   - Allowing arbitrary `<chore_module>` in config opens risks: a malicious or
     erroneous module could crash the app or execute harmful code. No built-in
     validation for module existence or behaviour compliance.
   - Invoking via Mix tasks assumes chores are safe for CLI; if they involve
     side effects (e.g., DB wipes), lack of auth/confirmation could be
     dangerous.

3. **Discoverability and Modularity**:
   - Listing chores (`maint.list`) via config scanning is fine, but if users
     add their own libraries, how are they discovered? Reloading config at
     runtime isn't straightforward in Elixir.
   - Chores tied to modules: Good, but without a standardized interface (e.g.,
     a Behaviour), extensibility is limited—developers might not know what to
     implement.

4. **Scalability and Integration**:
   - If chores grow complex or numerous, running them synchronously via Mix
     might not scale (e.g., long-running tasks block the shell). No queuing or
     scheduling mentioned.
   - Global config feels like an afterthought; better to keep everything
     project-local for reproducibility.

5. **LLM Integration ("Skills" Like Modern Techniques)**:
   - Using ReqLLM (assuming a library like `Req` with LLM extensions for HTTP
     calls to APIs like OpenAI) is a forward-thinking idea. Each chore could
     indeed wrap LLM calls, treating them as "skills" (e.g., a chore for
     "summarize logs" queries an LLM).
   - Flaw: Not all chores need LLMs—forcing it could bloat simple tasks.
     Dependency on external APIs introduces latency, costs, and failures (e.g.,
     rate limits, outages). No fallback for non-LLM modes.
   - "Skills" analogy: In LLM ecosystems (e.g., LangChain), skills/tools are
     functions callable by agents. Your chores could map to this, but without
     an agent orchestrator, it's just per-chore integration—potentially
     underutilizing the concept.

### Suggested Better Approach

Refine your concept into a more robust, Elixir-idiomatic framework. Focus on
behaviours for modularity, project-local persistence (e.g., via ETS or a config
file), and optional LLM hooks. Avoid global YAML; use Elixir config
exclusively, with runtime overrides if needed.

1. **Core Structure**:
   - Define a Behaviour for chores: `@callback run(opts :: map()) :: :ok |
     {:error, term()}`. This ensures all chores implement a standard interface.
   - Registry: Use an ETS table or GenServer to store registered chores (name,
     module, opts). Load defaults from `config.exs` at startup (e.g., `config
     :maint, chores: [%{name: "cleanup", module: MyApp.CleanupChore, opts:
     %{dry_run: true}}]`).
   - For persistence: If dynamic add/rm is crucial, store in a project-local
     file (e.g., `priv/maint/chores.json`) loaded at boot. Use Jason for
     serialization. Avoid global user config—keep it app-centric.

2. **Mix Tasks**:
   - Keep your proposed tasks, but implement them to interact with the
     registry:
     - `mix maint.run <name>`: Loads the registry, finds the module, calls
       `run/1`.
     - `mix maint.list`: Dumps registered chores.
     - `mix maint.add <name> <module> [--opts json_map]`: Parses input,
       validates module exists and implements behaviour (use
       `Code.ensure_compiled?/1` and behaviour checks), adds to registry and
       persists to file.
     - `mix maint.rm <name>`: Removes and persists.
   - Add safety: Confirmation prompts for rm/run, dry-run flags.

3. **Extensibility**:
   - Defaults: Ship with a module like `Maint.DefaultChores` that registers a
     library (e.g., DB vacuum, cache clear).
   - Field extensibility: Developers implement the behaviour in their app
     (e.g., `MyApp.CustomChore`), add to config or via `add`.
   - Third-party libraries: Publish Hex packages with chore modules (e.g., `hex
     pm install log_analyzer_chore`), then register them in config. Use Mix
     deps for inclusion.

4. **LLM Integration**:
   - Make it optional and modular: Provide a `Maint.LLMTool` module with
     helpers like `query_llm(prompt, model_opts) :: {:ok, response} | {:error,
     reason}`, using Req for HTTP (add OpenAI/Groq/etc. adapters).
   - "Skills" approach: Treat chores as composable skills. Add an orchestrator
     chore (e.g., `maint.run orchestrate <prompt>` ) that uses an LLM agent
     (via LangChain-inspired Elixir lib, or build simple chaining). Each chore
     exposes metadata (e.g., `@skill_desc "Summarizes logs"`), so the agent can
     select/call them dynamically.
   - Example: A chore module:
     ```elixir
     defmodule MyApp.LogSummaryChore do
       @behaviour Maint.Chore
       @skill_desc "Generate summary of application logs using LLM"

       def run(opts) do
         logs = fetch_logs(opts)
         prompt = "Summarize these logs: #{logs}"
         {:ok, response} = Maint.LLMTool.query_llm(prompt, %{model: "gpt-4"})
         IO.puts(response)
         :ok
       end
     end
     ```
   - Flaw mitigation: Config for LLM provider/keys, fallback to non-LLM mode
     (e.g., `opts[:no_llm] = true`). Monitor costs via metrics.

5. **Additional Improvements**:
   - Scheduling: Integrate with Quantum or Crontab for cron-like runs, aligning
     with "maintenance" goals.
   - Logging/Errors: Standardize output with Logger, handle exceptions
     gracefully.
   - Testing: Behaviour makes unit-testing chores easy.
   - Documentation: Use ExDoc with examples for each command and behaviour.

This approach fixes persistence/security issues, enhances modularity, and
better incorporates LLMs as optional "skills" without overcomplicating core
chores. It stays true to Elixir's strengths (behaviours, config, Mix) while
achieving your goals. If dynamic add/rm isn't essential, simplify by making
everything config-driven—no file persistence needed.
