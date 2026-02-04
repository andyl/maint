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

    name_width =
      chores
      |> Enum.map(fn chore -> chore[:name] |> to_string() |> String.length() end)
      |> Enum.max(fn -> 0 end)

    for chore <- chores do
      name = to_string(chore[:name])
      padded = String.pad_trailing(name, name_width)

      case Maint.shortdoc(chore[:module]) do
        nil -> Mix.shell().info("  #{padded}")
        desc -> Mix.shell().info("  #{padded} - #{desc}")
      end
    end

    Mix.shell().info("")
  end

  defp print_installed([]) do
    Mix.shell().info("No additional installed chore modules found.")
  end

  defp print_installed(modules) do
    Mix.shell().info("Installed but unconfigured:\n")

    for module <- modules do
      case Maint.shortdoc(module) do
        nil -> Mix.shell().info("  #{inspect(module)}")
        desc -> Mix.shell().info("  #{inspect(module)} - #{desc}")
      end
    end

    Mix.shell().info("")
  end
end
