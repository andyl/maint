defmodule Mix.Tasks.Maint.Rm do
  @moduledoc """
  Removes a chore from the project configuration.

  ## Usage

      mix maint.rm <chore_name> [--uninstall]

  ## Options

    * `--uninstall` - Also remove the mix.exs dependency via Igniter
    * `--yes` - Skip confirmation prompts
  """

  @shortdoc "Remove a maintenance chore"

  use Igniter.Mix.Task

  @impl Igniter.Mix.Task
  def info(_argv, _composing_task) do
    %Igniter.Mix.Task.Info{
      positional: [:chore_name],
      schema: [
        uninstall: :string,
        yes: :boolean
      ],
      defaults: [yes: false],
      aliases: [y: :yes]
    }
  end

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    chore_name = String.to_atom(igniter.args.positional.chore_name)
    opts = igniter.args.options

    igniter
    |> remove_chore_config(chore_name)
    |> maybe_uninstall_dep(opts)
  end

  defp remove_chore_config(igniter, chore_name) do
    Igniter.Project.Config.configure(
      igniter,
      "config.exs",
      :maint,
      [:chores],
      [],
      updater: fn zipper ->
        Igniter.Code.List.remove_from_list(zipper, fn item ->
          with {:ok, zipper} <- Igniter.Code.Keyword.get_key(item, :name),
               {:ok, ^chore_name} <- Igniter.Code.Common.expand_literal(zipper) do
            true
          else
            _ -> false
          end
        end)
      end
    )
  end

  defp maybe_uninstall_dep(igniter, opts) do
    case opts[:uninstall] do
      nil ->
        igniter

      dep_name ->
        Igniter.Project.Deps.remove_dep(igniter, String.to_atom(dep_name))
    end
  end
end
