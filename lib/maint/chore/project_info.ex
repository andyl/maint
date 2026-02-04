defmodule Maint.Chore.ProjectInfo do
  @moduledoc """
  Displays project metadata including app name, version, Elixir version, and dependency count.
  """

  @behaviour Maint.Chore

  @impl true
  def run(_opts) do
    config = Mix.Project.config()
    deps = config[:deps] || []

    info = """
    Project: #{config[:app]}
    Version: #{config[:version]}
    Elixir:  #{System.version()}
    OTP:     #{System.otp_release()}
    Deps:    #{length(deps)}\
    """

    {:ok, info}
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
