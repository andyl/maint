defmodule Mix.Tasks.Maint.Health do
  @moduledoc """
  Checks health of configured maintenance chores.

  Runs `health/0` on all configured chores, or a specific chore by name.

  ## Usage

      mix maint.health [chore_name]

  ## Examples

      mix maint.health              # Check all chores
      mix maint.health project_info # Check one chore
  """

  @shortdoc "Check maintenance chore health"

  use Mix.Task

  @impl Mix.Task
  def run(argv) do
    Mix.Task.run("app.start")

    case argv do
      [] -> check_all()
      [name | _] -> check_one(name)
    end
  end

  defp check_all do
    chores = Maint.configured_chores()

    if chores == [] do
      Mix.shell().info("No configured chores.")
    else
      Mix.shell().info("Health check for all configured chores:\n")
      Enum.each(chores, &check_chore/1)
    end
  end

  defp check_one(name) do
    case Maint.find_chore(name) do
      {:ok, chore} ->
        check_chore(chore)

      {:error, :not_found} ->
        Mix.raise("Chore #{inspect(name)} is not configured.")
    end
  end

  defp check_chore(chore) do
    name = chore[:name]
    module = chore[:module]

    case module.health() do
      {:ok, []} ->
        Mix.shell().info("  #{name}: healthy")

      {:ok, checks} ->
        Mix.shell().info("  #{name}: healthy (#{length(checks)} checks passed)")

      {:error, issues} ->
        Mix.shell().error("  #{name}: unhealthy")

        Enum.each(issues, fn issue ->
          Mix.shell().error("    - #{inspect(issue)}")
        end)
    end
  end
end
