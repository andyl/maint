defmodule Maint.Chore.DepsUnusedTest do
  use ExUnit.Case

  test "run/1 returns ok with a message" do
    assert {:ok, output} = Maint.Chore.DepsUnused.run([])
    assert is_binary(output)
  end

  test "health/0 returns ok" do
    assert {:ok, []} = Maint.Chore.DepsUnused.health()
  end

  test "setup/0 returns ok" do
    assert :ok = Maint.Chore.DepsUnused.setup()
  end
end
