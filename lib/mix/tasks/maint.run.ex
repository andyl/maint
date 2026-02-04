defmodule Mix.Tasks.Maint.Run do
  @moduledoc """
  Runs a configured maintenance chore.

  ## Usage

      mix maint.run <chore_name> [options]

  The chore name must match a configured chore. Any additional options are
  parsed and merged with the chore's configured opts (CLI opts take precedence).

  ## Examples

      mix maint.run project_info
      mix maint.run deps_outdated
  """

  @shortdoc "Run a maintenance chore"

  use Mix.Task

  @impl Mix.Task
  def run([]) do
    Mix.raise("Usage: mix maint.run <chore_name> [options]")
  end

  def run([name | rest]) do
    Mix.Task.run("app.start")

    {cli_opts, _, _} = OptionParser.parse(rest, strict: [])

    case Maint.find_chore(name) do
      {:ok, chore} ->
        module = chore[:module]
        config_opts = chore[:opts] || []
        merged_opts = Keyword.merge(config_opts, cli_opts)

        run_requirements(module, MapSet.new())

        case module.run(merged_opts) do
          {:ok, result} ->
            Mix.shell().info(format_result(result))

          {:error, reason} ->
            Mix.shell().error("Chore #{name} failed: #{inspect(reason)}")
        end

      {:error, :not_found} ->
        Mix.raise(
          "Chore #{inspect(name)} is not configured. Run `mix maint.ls` to see available chores."
        )
    end
  end

  defp run_requirements(module, already_run) do
    Maint.requirements(module)
    |> Enum.reduce(already_run, fn req_name, acc ->
      if MapSet.member?(acc, req_name) do
        acc
      else
        case Maint.find_chore(req_name) do
          {:ok, req_chore} ->
            req_module = req_chore[:module]
            acc = run_requirements(req_module, acc)

            Mix.shell().info("Running requirement: #{req_name}")

            case req_module.run(req_chore[:opts] || []) do
              {:ok, _} ->
                MapSet.put(acc, req_name)

              {:error, reason} ->
                Mix.raise("Requirement #{req_name} failed: #{inspect(reason)}")
            end

          {:error, :not_found} ->
            Mix.raise(
              "Required chore #{inspect(req_name)} is not configured. " <>
                "Add it with `mix maint.add`."
            )
        end
      end
    end)
  end

  defp format_result(result) when is_binary(result), do: result
  defp format_result(result), do: inspect(result, pretty: true)
end
