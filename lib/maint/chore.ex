defmodule Maint.Chore do
  @moduledoc """
  Behaviour for maintenance chore modules.

  A chore is a maintenance task that can be run, health-checked, and auto-fixed.
  Chore modules live in the `Maint.Chore.*` namespace.

  ## Module Attributes

    * `@shortdoc` - a one-line description shown by `mix maint.ls`
    * `@moduledoc` - full documentation shown by `mix maint.help <chore>`
    * `@requirements` - list of chore names (atoms) that must run before this one

  ## Example

      defmodule Maint.Chore.MyChore do
        use Maint.Chore

        @shortdoc "Does something useful"
        @requirements [:project_info]

        @impl true
        def run(opts) do
          {:ok, "done"}
        end
      end
  """

  @callback run(opts :: keyword()) :: {:ok, term()} | {:error, term()}
  @callback health() :: {:ok, list()} | {:error, list()}
  @callback setup() :: :ok | {:error, term()}

  defmacro __using__(_opts) do
    quote do
      @behaviour Maint.Chore

      Module.register_attribute(__MODULE__, :shortdoc, persist: true)
      Module.register_attribute(__MODULE__, :requirements, persist: true)

      @requirements []

      @impl true
      def health, do: {:ok, []}

      @impl true
      def setup, do: :ok

      defoverridable health: 0, setup: 0
    end
  end
end
