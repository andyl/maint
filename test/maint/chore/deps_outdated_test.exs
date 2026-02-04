defmodule Maint.Chore.DepsOutdatedTest do
  use ExUnit.Case

  test "run/1 returns ok with output" do
    assert {:ok, output} = Maint.Chore.DepsOutdated.run([])
    assert is_binary(output)
  end

  test "health/0 returns ok" do
    assert {:ok, []} = Maint.Chore.DepsOutdated.health()
  end

  test "setup/0 returns ok" do
    assert :ok = Maint.Chore.DepsOutdated.setup()
  end
end
