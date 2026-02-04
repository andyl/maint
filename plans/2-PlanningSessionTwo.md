# Maint App - Planning Session Two

Refinement of ideas following Planning Session One

## Decisions Following Planning Session One

- stick with the name 'chore' 
- drop the idea of:
    * global config 
    * scheduling or background jobs 
    * yaml parsing 
- add the idea of:
    * logging & error logs: use by 'mix maint.chat' for LLM context 
- elaboration - about chores:
    * chore modules are always in the namespace `Maint.Chore` (inspired by Mix tasks...) 
    * chore modules can be in any application, installed as a mix.exs dependency 
    * chore modules implement the `Maint.Chore` behavior:
        + a `run` function 
        + a `health` function 
        + a `setup` function
    * chores have two states - installed and configured:
        + installed means the chore module is present in the app 
        + installed means the chore module is loaded as a mix.exs dependency
        + configured means the chore module is configured in config.exs (name, module, options)
    * the maint app will have a set of default chores, which could include:
        + list tasks 
- there should be two methods to install the maint app:
    * manual install: add readme instructions to update mix.exs dependency and config.exs setup 
    * igniter install: `mix igniter.install maint` auto-generates mix.exs and config.exs configs

The mix tasks are: 

- phase 1 | mix maint.ls     | list installed and configured chores
- phase 1 | mix maint.add    | install and/or configure chores
- phase 1 | mix maint.rm     | uninstall and/or unconfigure chores
- phase 1 | mix maint.run    | run a chore
- phase 2 | mix maint.health | check health of maint system and all chores
- phase 2 | mix maint.setup  | install and configure chore dependencies
- phase 3 | mix maint.chat   | chat with a maint agent
- phase 4 | mix maint.dash   | show a TUI for the maint system

**maint.ls**

List installed and configured chores - maybe in a table showing
installed/configured status - maybe with a command line option to only show
configured chores.  The default should probably be just configured chores.

**maint.add** 

Add a chore, which can mean either install a chore, or configure a chore.

Install probably takes an ingiter-style spec, and adds an item to mix.exs
dependencies (using igniter).  After installing, there should be a warning if
the package does not contain a `lib/maint` directory.  

Configure takes options to setup config.exs. The editing of the config.exs
probably should also be done with igniter.  There should be command-line flags
or options to distinguish between 'install' and 'configure'.

**maint.rm**

Remove the config.exs configuration (takes a chore name) or the mix.exs dependency (takes an igniter-style argument).  

**maint.run**

Run a chore.

**maint.health** 

A chore may require 
- an LLM API Key 
- a git configuration 
- a github account 
- an installed 'gh' utility
- an elixir dependency 
- etc.

Each chore should implement the `health` function to introspect the host
machine and report missing requirements.

The `health` function should probably be invoked before calling the `run`
function.

**maint.setup** 

Each chore should implement the `setup` function to auto-fix missing
requirements as possible.  When not possible, a text message should be issued
with instructions for a manual fix.

**maint.chat**

This task provides a LLM layer.  The LLM can reason across all chores and mix
tasks.  Questions that might be ask during chat might include:

- What maintenance needs to be performed?
- When was the last time I updated dependencies?
- What issues were filed today?
- Are my dependencies up to date?
- How can I test my CI/CD setup? 
- Please close issue #224
- ...

The LLM integration should be implemented using Jido, Jido.AI and ReqLLM.

**maint.dash**

In the distant future, it might be great to have a maintenance TUI, with a
chat interface, an ability to view logs and run chores.

## LLM Integration 

All LLM integration is to be done via the 'chat' task, or in the Chore modules.
LLM integration in the Chore modules is an optional choice made by the Chore
author.  Most Chores probably will not integrate with LLMs.  

Mix.Tasks.Maint.Chat will use Jido, JidoAI and ReqLLM.  Chore authors are
encouraged to use the same tool set.

We will not provide as module `Maint.LLMTool`, but will instead call directly
to the Jido tools.

## Questions:

- Are there downsides to force chore modules to always be in the namespace
  `Maint.Chores`?  I think it is good for discoverability and because it uses a
  well-understood pattern used by `Mix.Tasks`.
- Please critique the names of the mix tasks (ls, add, rm, run, chat, health, setup, dash), identify potential problems and suggest improvements
- This should work for linux/mac.  But Windows?  I think windows support is too much overhead.
- Should the 'add' be broken into 'install' and 'configure'?  I'd rather stick with just 'add'.  
