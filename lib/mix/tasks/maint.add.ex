defmodule Mix.Tasks.Maint.Add do
  @moduledoc """
  Adds a chore to the project.

  Two modes:

  * **Install** — Adds a hex package as a dependency and configures the chore:

        mix maint.add --install <hex_package> --module <ModuleName> --name <chore_name>

  * **Configure** — Configures an already-installed chore module:

        mix maint.add --configure <ModuleName> --name <chore_name>

  ## Options

    * `--install` - Hex package to install as a dependency
    * `--configure` - Module name of an already-installed chore to configure
    * `--name` - Name for the chore in config (defaults to module's short name, snake_cased)
    * `--yes` - Skip confirmation prompts
  """

  @shortdoc "Add a maintenance chore"

  use Igniter.Mix.Task

  @impl Igniter.Mix.Task
  def info(_argv, _composing_task) do
    %Igniter.Mix.Task.Info{
      schema: [
        install: :string,
        configure: :string,
        name: :string,
        yes: :boolean
      ],
      defaults: [yes: false],
      aliases: [y: :yes]
    }
  end

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    opts = igniter.args.options

    cond do
      opts[:install] ->
        install_and_configure(igniter, opts)

      opts[:configure] ->
        configure_chore(igniter, opts)

      true ->
        Igniter.add_issue(igniter, "Must specify either --install or --configure")
    end
  end

  defp install_and_configure(igniter, opts) do
    package = opts[:install]
    {dep_name, version} = Igniter.Project.Deps.determine_dep_type_and_version!(package)

    igniter
    |> Igniter.Project.Deps.add_dep({dep_name, version}, yes?: opts[:yes])
    |> then(fn igniter ->
      if opts[:configure] || opts[:name] do
        configure_chore(igniter, opts)
      else
        Igniter.add_notice(
          igniter,
          "Package #{package} added. Use `mix maint.add --configure <Module> --name <name>` to configure a chore from it."
        )
      end
    end)
  end

  defp configure_chore(igniter, opts) do
    module_string = opts[:configure] || raise "Missing --configure flag"

    module =
      module_string
      |> ensure_elixir_prefix()
      |> String.to_atom()

    chore_name =
      if opts[:name] do
        String.to_atom(opts[:name])
      else
        derive_chore_name(module)
      end

    chore_entry =
      Sourceror.parse_string!("[name: :#{chore_name}, module: #{inspect(module)}, opts: []]")

    Igniter.Project.Config.configure(
      igniter,
      "config.exs",
      :maint,
      [:chores],
      [{:code, chore_entry}],
      updater: fn zipper ->
        Igniter.Code.List.append_new_to_list(zipper, {:code, chore_entry})
      end
    )
  end

  defp ensure_elixir_prefix("Elixir." <> _ = name), do: name
  defp ensure_elixir_prefix(name), do: "Elixir." <> name

  defp derive_chore_name(module) do
    module
    |> Module.split()
    |> List.last()
    |> Macro.underscore()
    |> String.to_atom()
  end
end
