defmodule Mix.Tasks.Maint.RunTest do
  use ExUnit.Case
  import ExUnit.CaptureIO

  setup do
    original = Application.get_env(:maint, :chores, [])
    on_exit(fn -> Application.put_env(:maint, :chores, original) end)
    :ok
  end

  test "runs a configured chore" do
    Application.put_env(:maint, :chores, [
      [name: :test, module: Maint.Chore.TestChore, opts: []]
    ])

    output = capture_io(fn -> Mix.Tasks.Maint.Run.run(["test"]) end)
    assert output =~ "test chore ran"
  end

  test "merges config opts with CLI opts" do
    Application.put_env(:maint, :chores, [
      [name: :test, module: Maint.Chore.TestChore, opts: [foo: "bar"]]
    ])

    output = capture_io(fn -> Mix.Tasks.Maint.Run.run(["test"]) end)
    assert output =~ "foo"
  end

  test "raises for missing chore name" do
    assert_raise Mix.Error, fn -> Mix.Tasks.Maint.Run.run([]) end
  end

  test "raises for unconfigured chore" do
    Application.put_env(:maint, :chores, [])

    assert_raise Mix.Error, ~r/not configured/, fn ->
      Mix.Tasks.Maint.Run.run(["nonexistent"])
    end
  end

  test "prints error for failing chore" do
    Application.put_env(:maint, :chores, [
      [name: :failing, module: Maint.Chore.FailingChore, opts: []]
    ])

    output = capture_io(:stderr, fn -> Mix.Tasks.Maint.Run.run(["failing"]) end)
    assert output =~ "failed"
  end
end
