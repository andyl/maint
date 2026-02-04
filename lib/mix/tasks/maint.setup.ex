defmodule Mix.Tasks.Maint.Setup do
  @moduledoc """
  Runs setup for configured maintenance chores.

  Calls `setup/0` on all configured chores (or a named chore) to auto-fix
  missing requirements. Reports what was fixed and what needs manual action.

  ## Usage

      mix maint.setup [chore_name]

  ## Examples

      mix maint.setup              # Setup all chores
      mix maint.setup deps_outdated # Setup one chore
  """

  @shortdoc "Auto-fix maintenance chore requirements"

  use Mix.Task

  @impl Mix.Task
  def run(argv) do
    Mix.Task.run("app.start")

    case argv do
      [] -> setup_all()
      [name | _] -> setup_one(name)
    end
  end

  defp setup_all do
    chores = Maint.configured_chores()

    if chores == [] do
      Mix.shell().info("No configured chores.")
    else
      Mix.shell().info("Running setup for all configured chores:\n")
      Enum.each(chores, &setup_chore/1)
    end
  end

  defp setup_one(name) do
    case Maint.find_chore(name) do
      {:ok, chore} ->
        setup_chore(chore)

      {:error, :not_found} ->
        Mix.raise("Chore #{inspect(name)} is not configured.")
    end
  end

  defp setup_chore(chore) do
    name = chore[:name]
    module = chore[:module]

    case module.setup() do
      :ok ->
        Mix.shell().info("  #{name}: setup complete")

      {:error, reason} ->
        Mix.shell().error("  #{name}: setup failed — #{inspect(reason)}")
    end
  end
end
