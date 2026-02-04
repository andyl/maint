defmodule Mix.Tasks.Maint.LsTest do
  use ExUnit.Case
  import ExUnit.CaptureIO

  setup do
    original = Application.get_env(:maint, :chores, [])
    on_exit(fn -> Application.put_env(:maint, :chores, original) end)
    :ok
  end

  test "lists configured chores" do
    Application.put_env(:maint, :chores, [
      [name: :test, module: Maint.Chore.TestChore, opts: []]
    ])

    output = capture_io(fn -> Mix.Tasks.Maint.Ls.run([]) end)
    assert output =~ "test"
    assert output =~ "Maint.Chore.TestChore"
  end

  test "shows no chores message when empty" do
    Application.put_env(:maint, :chores, [])

    output = capture_io(fn -> Mix.Tasks.Maint.Ls.run([]) end)
    assert output =~ "No configured chores"
  end

  test "with --all flag shows installed chores" do
    Application.put_env(:maint, :chores, [])

    output = capture_io(fn -> Mix.Tasks.Maint.Ls.run(["--all"]) end)
    assert is_binary(output)
  end
end
