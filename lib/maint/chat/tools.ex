defmodule Maint.Chat.Tools do
  @moduledoc """
  ReqLLM tool definitions for the Maint chat interface.

  Provides tools that the LLM can invoke to interact with the chore system:
  listing chores, running them, checking health, and running setup.
  """

  alias ReqLLM.Tool

  @doc """
  Returns the list of all chat tools.
  """
  @spec all() :: [Tool.t()]
  def all do
    [list_chores(), run_chore(), check_health(), run_setup()]
  end

  @doc """
  Tool: list all configured chores.
  """
  def list_chores do
    Tool.new!(
      name: "list_chores",
      description: "List all configured maintenance chores with their name, module, and options",
      parameter_schema: [],
      callback: &list_chores_callback/1
    )
  end

  @doc """
  Tool: run a configured chore by name.
  """
  def run_chore do
    Tool.new!(
      name: "run_chore",
      description:
        "Run a configured maintenance chore by name. Returns the chore's output or error.",
      parameter_schema: [
        chore_name: [type: :string, required: true, doc: "Name of the chore to run"]
      ],
      callback: &run_chore_callback/1
    )
  end

  @doc """
  Tool: check health of chores.
  """
  def check_health do
    Tool.new!(
      name: "check_health",
      description:
        "Check the health of a named chore, or all configured chores if no name is given. " <>
          "Reports missing requirements and issues.",
      parameter_schema: [
        chore_name: [
          type: :string,
          required: false,
          doc: "Optional chore name. If omitted, checks all configured chores."
        ]
      ],
      callback: &check_health_callback/1
    )
  end

  @doc """
  Tool: run setup for chores.
  """
  def run_setup do
    Tool.new!(
      name: "run_setup",
      description:
        "Run setup for a named chore, or all configured chores if no name is given. " <>
          "Attempts to auto-fix missing requirements.",
      parameter_schema: [
        chore_name: [
          type: :string,
          required: false,
          doc: "Optional chore name. If omitted, runs setup for all configured chores."
        ]
      ],
      callback: &run_setup_callback/1
    )
  end

  # Callbacks

  @doc false
  def list_chores_callback(_args) do
    chores = Maint.configured_chores()

    case chores do
      [] ->
        {:ok, "No chores are currently configured."}

      chores ->
        lines =
          Enum.map_join(chores, "\n", fn chore ->
            base = "- #{chore[:name]} (#{inspect(chore[:module])})"

            case Maint.shortdoc(chore[:module]) do
              nil -> base
              desc -> "#{base} - #{desc}"
            end
          end)

        {:ok, "Configured chores:\n#{lines}"}
    end
  end

  @doc false
  def run_chore_callback(args) do
    name = args[:chore_name] || args["chore_name"]

    case Maint.find_chore(name) do
      {:ok, chore} ->
        module = chore[:module]
        opts = chore[:opts] || []

        case module.run(opts) do
          {:ok, result} when is_binary(result) -> {:ok, result}
          {:ok, result} -> {:ok, inspect(result, pretty: true)}
          {:error, reason} -> {:ok, "Chore #{name} failed: #{inspect(reason)}"}
        end

      {:error, :not_found} ->
        {:ok,
         "Chore '#{name}' is not configured. Use the list_chores tool to see available chores."}
    end
  end

  @doc false
  def check_health_callback(args) do
    name = args[:chore_name] || args["chore_name"]

    if name do
      check_one_health(name)
    else
      check_all_health()
    end
  end

  @doc false
  def run_setup_callback(args) do
    name = args[:chore_name] || args["chore_name"]

    if name do
      setup_one(name)
    else
      setup_all()
    end
  end

  defp check_one_health(name) do
    case Maint.find_chore(name) do
      {:ok, chore} ->
        result = format_health(chore[:name], chore[:module])
        {:ok, result}

      {:error, :not_found} ->
        {:ok, "Chore '#{name}' is not configured."}
    end
  end

  defp check_all_health do
    chores = Maint.configured_chores()

    case chores do
      [] ->
        {:ok, "No chores are configured."}

      chores ->
        results = Enum.map_join(chores, "\n", fn c -> format_health(c[:name], c[:module]) end)
        {:ok, "Health check results:\n#{results}"}
    end
  end

  defp format_health(name, module) do
    case module.health() do
      {:ok, []} -> "- #{name}: healthy"
      {:ok, checks} -> "- #{name}: healthy (#{length(checks)} checks passed)"
      {:error, issues} -> "- #{name}: unhealthy — #{inspect(issues)}"
    end
  end

  defp setup_one(name) do
    case Maint.find_chore(name) do
      {:ok, chore} ->
        result = format_setup(chore[:name], chore[:module])
        {:ok, result}

      {:error, :not_found} ->
        {:ok, "Chore '#{name}' is not configured."}
    end
  end

  defp setup_all do
    chores = Maint.configured_chores()

    case chores do
      [] ->
        {:ok, "No chores are configured."}

      chores ->
        results = Enum.map_join(chores, "\n", fn c -> format_setup(c[:name], c[:module]) end)
        {:ok, "Setup results:\n#{results}"}
    end
  end

  defp format_setup(name, module) do
    case module.setup() do
      :ok -> "- #{name}: setup complete"
      {:error, reason} -> "- #{name}: setup failed — #{inspect(reason)}"
    end
  end
end
