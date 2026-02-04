defmodule Maint.Chore.DepsOutdated do
  @moduledoc """
  Checks for outdated Hex dependencies.

  Wraps `mix hex.outdated` and returns its output.
  """

  @behaviour Maint.Chore

  @impl true
  def run(_opts) do
    case System.cmd("mix", ["hex.outdated"], stderr_to_stdout: true) do
      {output, 0} -> {:ok, output}
      {output, _} -> {:ok, output}
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
end
