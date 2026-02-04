defmodule Maint.Chore.TestChore do
  @moduledoc false

  @behaviour Maint.Chore

  @impl true
  def run(opts) do
    {:ok, "test chore ran with opts: #{inspect(opts)}"}
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

defmodule Maint.Chore.FailingChore do
  @moduledoc false

  @behaviour Maint.Chore

  @impl true
  def run(_opts) do
    {:error, "something went wrong"}
  end

  @impl true
  def health do
    {:error, ["missing API key", "missing config"]}
  end

  @impl true
  def setup do
    {:error, "cannot auto-fix"}
  end
end
