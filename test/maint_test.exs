defmodule MaintTest do
  use ExUnit.Case

  setup do
    original = Application.get_env(:maint, :chores, [])
    on_exit(fn -> Application.put_env(:maint, :chores, original) end)
    :ok
  end

  describe "configured_chores/0" do
    test "returns empty list when no chores configured" do
      Application.put_env(:maint, :chores, [])
      assert Maint.configured_chores() == []
    end

    test "returns configured chores" do
      chores = [[name: :test, module: Maint.Chore.TestChore, opts: []]]
      Application.put_env(:maint, :chores, chores)
      assert Maint.configured_chores() == chores
    end
  end

  describe "find_chore/1" do
    test "finds a chore by atom name" do
      chores = [[name: :test, module: Maint.Chore.TestChore, opts: []]]
      Application.put_env(:maint, :chores, chores)

      assert {:ok, chore} = Maint.find_chore(:test)
      assert chore[:module] == Maint.Chore.TestChore
    end

    test "finds a chore by string name" do
      chores = [[name: :test, module: Maint.Chore.TestChore, opts: []]]
      Application.put_env(:maint, :chores, chores)

      assert {:ok, chore} = Maint.find_chore("test")
      assert chore[:module] == Maint.Chore.TestChore
    end

    test "returns error for unknown chore" do
      Application.put_env(:maint, :chores, [])
      assert {:error, :not_found} = Maint.find_chore(:nonexistent)
    end

    test "returns error for unknown string chore" do
      Application.put_env(:maint, :chores, [])
      assert {:error, :not_found} = Maint.find_chore("totally_unknown_atom_xyz")
    end
  end

  describe "installed_chores/0" do
    test "returns a list of modules" do
      chores = Maint.installed_chores()
      assert is_list(chores)
    end
  end

  describe "implements_chore?/1" do
    test "returns true for a chore module" do
      assert Maint.implements_chore?(Maint.Chore.TestChore)
    end

    test "returns false for a non-chore module" do
      refute Maint.implements_chore?(String)
    end

    test "returns false for non-existent module" do
      refute Maint.implements_chore?(NonExistent.Module)
    end
  end
end
