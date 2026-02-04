defmodule Maint.Chore do
  @moduledoc """
  Behaviour for maintenance chore modules.

  A chore is a maintenance task that can be run, health-checked, and auto-fixed.
  Chore modules live in the `Maint.Chore.*` namespace.
  """

  @callback run(opts :: keyword()) :: {:ok, term()} | {:error, term()}
  @callback health() :: {:ok, list()} | {:error, list()}
  @callback setup() :: :ok | {:error, term()}
end
