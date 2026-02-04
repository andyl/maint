defmodule Maint.Chore.DepsOutdated do
  @moduledoc """
  Checks for outdated Hex dependencies.

  Wraps `mix hex.outdated` and returns its output.
  """

  use Maint.Chore

  @shortdoc "Check for outdated Hex dependencies"

  @impl true
  def run(_opts) do
    case System.cmd("mix", ["hex.outdated"], stderr_to_stdout: true) do
      {output, 0} -> {:ok, output}
      {output, _} -> {:ok, output}
    end
  end
end
