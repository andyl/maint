defmodule Mix.Tasks.Maint.Ls do
  @moduledoc """
  Lists maintenance chores.

  By default, shows only configured chores. Use `--all` to also show
  installed but unconfigured chore modules.

  ## Usage

      mix maint.ls [--all]

  ## Options

    * `--all` - Show both configured and installed-but-unconfigured chores
  """

  @shortdoc "List maintenance chores"

  use Mix.Task

  @impl Mix.Task
  def run(argv) do
    Mix.Task.run("app.start")

    {opts, _, _} = OptionParser.parse(argv, strict: [all: :boolean])
    show_all? = Keyword.get(opts, :all, false)

    configured = Maint.configured_chores()

    if show_all? do
      configured_modules = MapSet.new(configured, fn chore -> chore[:module] end)

      installed =
        Maint.installed_chores()
        |> Enum.reject(&MapSet.member?(configured_modules, &1))

      print_chores(configured, :configured)
      print_installed(installed)
    else
      print_chores(configured, :configured)
    end
  end

  defp print_chores([], :configured) do
    Mix.shell().info("No configured chores.")
  end

  defp print_chores(chores, :configured) do
    Mix.shell().info("Configured chores:\n")

    for chore <- chores do
      name = chore[:name]
      module = inspect(chore[:module])
      Mix.shell().info("  #{name} (#{module})")
    end

    Mix.shell().info("")
  end

  defp print_installed([]) do
    Mix.shell().info("No additional installed chore modules found.")
  end

  defp print_installed(modules) do
    Mix.shell().info("Installed but unconfigured:\n")

    for module <- modules do
      Mix.shell().info("  #{inspect(module)}")
    end

    Mix.shell().info("")
  end
end
