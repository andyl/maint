defmodule Maint do
  @moduledoc """
  Core module for the Maint maintenance automation framework.

  Provides functions for reading chore configuration, looking up chores,
  and discovering installed chore modules.
  """

  @doc """
  Returns the list of configured chores from application config.

  Each chore is a keyword list with `:name`, `:module`, and `:opts` keys.
  """
  @spec configured_chores() :: [keyword()]
  def configured_chores do
    Application.get_env(:maint, :chores, [])
  end

  @doc """
  Finds a configured chore by name (atom or string).

  Returns `{:ok, chore}` or `{:error, :not_found}`.
  """
  @spec find_chore(atom() | String.t()) :: {:ok, keyword()} | {:error, :not_found}
  def find_chore(name) when is_binary(name) do
    find_chore(String.to_existing_atom(name))
  rescue
    ArgumentError -> {:error, :not_found}
  end

  def find_chore(name) when is_atom(name) do
    case Enum.find(configured_chores(), fn chore -> chore[:name] == name end) do
      nil -> {:error, :not_found}
      chore -> {:ok, chore}
    end
  end

  @doc """
  Discovers all modules implementing the `Maint.Chore` behaviour across loaded applications.
  """
  @spec installed_chores() :: [module()]
  def installed_chores do
    for {app, _, _} <- Application.loaded_applications(),
        {:ok, modules} <- [:application.get_key(app, :modules)],
        module <- modules,
        implements_chore?(module) do
      module
    end
  end

  @doc "Returns the `@shortdoc` string for a chore module, or `nil`."
  @spec shortdoc(module()) :: String.t() | nil
  def shortdoc(module) do
    module.__info__(:attributes)
    |> Keyword.get(:shortdoc, [nil])
    |> List.first()
  rescue
    _ -> nil
  end

  @doc "Returns the `@moduledoc` string for a chore module, or `nil`."
  @spec moduledoc(module()) :: String.t() | nil
  def moduledoc(module) do
    case Code.fetch_docs(module) do
      {:docs_v1, _, _, _, %{"en" => doc}, _, _} -> doc
      _ -> nil
    end
  end

  @doc "Returns the `@requirements` list for a chore module."
  @spec requirements(module()) :: [atom()]
  def requirements(module) do
    module.__info__(:attributes)
    |> Keyword.get(:requirements, [[]])
    |> List.first()
  rescue
    _ -> []
  end

  @doc """
  Checks whether a module implements the `Maint.Chore` behaviour.
  """
  @spec implements_chore?(module()) :: boolean()
  def implements_chore?(module) do
    behaviours =
      module.module_info(:attributes)
      |> Keyword.get_values(:behaviour)
      |> List.flatten()

    Maint.Chore in behaviours
  rescue
    _ -> false
  end
end
