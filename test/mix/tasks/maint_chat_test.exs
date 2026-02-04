defmodule Mix.Tasks.Maint.ChatTest do
  use ExUnit.Case

  test "task module exists" do
    assert Code.ensure_loaded?(Mix.Tasks.Maint.Chat)
  end

  test "task has run/1" do
    assert function_exported?(Mix.Tasks.Maint.Chat, :run, 1)
  end
end
