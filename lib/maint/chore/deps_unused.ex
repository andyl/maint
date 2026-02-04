defmodule Maint.Chore.DepsUnused do
  @moduledoc """
  Identifies potentially unused dependencies by scanning the codebase.

  Compares declared mix.exs dependencies against modules actually referenced
  in `lib/` source files. Dependencies that appear to have no references
  are flagged as potentially unused.
  """

  @behaviour Maint.Chore

  @impl true
  def run(_opts) do
    config = Mix.Project.config()
    declared_deps = Keyword.keys(config[:deps] || [])

    referenced =
      lib_files()
      |> Enum.flat_map(&extract_references/1)
      |> MapSet.new()

    potentially_unused =
      Enum.filter(declared_deps, fn dep ->
        dep_modules = get_dep_modules(dep)
        not Enum.any?(dep_modules, &MapSet.member?(referenced, &1))
      end)

    case potentially_unused do
      [] ->
        {:ok, "All dependencies appear to be in use."}

      deps ->
        list = Enum.map_join(deps, "\n  ", &Atom.to_string/1)
        {:ok, "Potentially unused dependencies:\n  #{list}"}
    end
  end

  @impl true
  def health do
    {:ok, []}
  end

  @impl true
  def setup do
    :ok
  end

  defp lib_files do
    Path.wildcard("lib/**/*.ex")
  end

  defp extract_references(file) do
    file
    |> File.read!()
    |> then(fn content ->
      Regex.scan(~r/(?:alias|import|use|require)\s+([\w.]+)/, content)
      |> Enum.map(fn [_, module] -> module end)
    end)
  end

  defp get_dep_modules(dep) do
    case :application.get_key(dep, :modules) do
      {:ok, modules} ->
        Enum.map(modules, fn mod -> inspect(mod) end)

      :undefined ->
        [dep |> Atom.to_string() |> Macro.camelize()]
    end
  end
end
