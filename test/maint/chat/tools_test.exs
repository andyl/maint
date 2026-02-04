defmodule Maint.Chat.ToolsTest do
  use ExUnit.Case

  setup do
    original = Application.get_env(:maint, :chores, [])
    on_exit(fn -> Application.put_env(:maint, :chores, original) end)
    :ok
  end

  describe "all/0" do
    test "returns four tools" do
      tools = Maint.Chat.Tools.all()
      assert length(tools) == 4
      names = Enum.map(tools, & &1.name)
      assert "list_chores" in names
      assert "run_chore" in names
      assert "check_health" in names
      assert "run_setup" in names
    end
  end

  describe "list_chores_callback/1" do
    test "returns message when no chores configured" do
      Application.put_env(:maint, :chores, [])
      assert {:ok, msg} = Maint.Chat.Tools.list_chores_callback(%{})
      assert msg =~ "No chores"
    end

    test "returns chore list when configured" do
      Application.put_env(:maint, :chores, [
        [name: :test, module: Maint.Chore.TestChore, opts: []]
      ])

      assert {:ok, msg} = Maint.Chat.Tools.list_chores_callback(%{})
      assert msg =~ "test"
      assert msg =~ "Maint.Chore.TestChore"
    end
  end

  describe "run_chore_callback/1" do
    test "runs a configured chore" do
      Application.put_env(:maint, :chores, [
        [name: :test, module: Maint.Chore.TestChore, opts: []]
      ])

      assert {:ok, msg} = Maint.Chat.Tools.run_chore_callback(%{chore_name: "test"})
      assert msg =~ "test chore ran"
    end

    test "handles string keys from LLM" do
      Application.put_env(:maint, :chores, [
        [name: :test, module: Maint.Chore.TestChore, opts: []]
      ])

      assert {:ok, msg} = Maint.Chat.Tools.run_chore_callback(%{"chore_name" => "test"})
      assert msg =~ "test chore ran"
    end

    test "returns error for unknown chore" do
      Application.put_env(:maint, :chores, [])
      assert {:ok, msg} = Maint.Chat.Tools.run_chore_callback(%{chore_name: "nonexistent"})
      assert msg =~ "not configured"
    end

    test "reports chore failure" do
      Application.put_env(:maint, :chores, [
        [name: :failing, module: Maint.Chore.FailingChore, opts: []]
      ])

      assert {:ok, msg} = Maint.Chat.Tools.run_chore_callback(%{chore_name: "failing"})
      assert msg =~ "failed"
    end
  end

  describe "check_health_callback/1" do
    test "checks all chores when no name given" do
      Application.put_env(:maint, :chores, [
        [name: :test, module: Maint.Chore.TestChore, opts: []]
      ])

      assert {:ok, msg} = Maint.Chat.Tools.check_health_callback(%{})
      assert msg =~ "test"
      assert msg =~ "healthy"
    end

    test "checks a specific chore" do
      Application.put_env(:maint, :chores, [
        [name: :test, module: Maint.Chore.TestChore, opts: []]
      ])

      assert {:ok, msg} = Maint.Chat.Tools.check_health_callback(%{chore_name: "test"})
      assert msg =~ "healthy"
    end

    test "reports unhealthy chore" do
      Application.put_env(:maint, :chores, [
        [name: :failing, module: Maint.Chore.FailingChore, opts: []]
      ])

      assert {:ok, msg} = Maint.Chat.Tools.check_health_callback(%{chore_name: "failing"})
      assert msg =~ "unhealthy"
    end
  end

  describe "run_setup_callback/1" do
    test "runs setup for all chores" do
      Application.put_env(:maint, :chores, [
        [name: :test, module: Maint.Chore.TestChore, opts: []]
      ])

      assert {:ok, msg} = Maint.Chat.Tools.run_setup_callback(%{})
      assert msg =~ "setup complete"
    end

    test "runs setup for a specific chore" do
      Application.put_env(:maint, :chores, [
        [name: :test, module: Maint.Chore.TestChore, opts: []]
      ])

      assert {:ok, msg} = Maint.Chat.Tools.run_setup_callback(%{chore_name: "test"})
      assert msg =~ "setup complete"
    end

    test "reports setup failure" do
      Application.put_env(:maint, :chores, [
        [name: :failing, module: Maint.Chore.FailingChore, opts: []]
      ])

      assert {:ok, msg} = Maint.Chat.Tools.run_setup_callback(%{chore_name: "failing"})
      assert msg =~ "setup failed"
    end
  end
end
