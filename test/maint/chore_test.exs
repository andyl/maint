defmodule Maint.ChoreTest do
  use ExUnit.Case

  describe "Maint.Chore behaviour" do
    test "TestChore implements all callbacks" do
      assert {:ok, _} = Maint.Chore.TestChore.run([])
      assert {:ok, _} = Maint.Chore.TestChore.health()
      assert :ok = Maint.Chore.TestChore.setup()
    end

    test "FailingChore returns error tuples" do
      assert {:error, _} = Maint.Chore.FailingChore.run([])
      assert {:error, _} = Maint.Chore.FailingChore.health()
      assert {:error, _} = Maint.Chore.FailingChore.setup()
    end
  end
end
