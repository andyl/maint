defmodule MaintTest do
  use ExUnit.Case
  doctest Maint

  test "greets the world" do
    assert Maint.hello() == :world
  end
end
