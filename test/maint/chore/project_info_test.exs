defmodule Maint.Chore.ProjectInfoTest do
  use ExUnit.Case

  test "run/1 returns project info" do
    assert {:ok, info} = Maint.Chore.ProjectInfo.run([])
    assert info =~ "Project:"
    assert info =~ "Version:"
    assert info =~ "Elixir:"
    assert info =~ "Deps:"
  end

  test "health/0 returns ok" do
    assert {:ok, []} = Maint.Chore.ProjectInfo.health()
  end

  test "setup/0 returns ok" do
    assert :ok = Maint.Chore.ProjectInfo.setup()
  end
end
