defmodule DistTestTest do
  use ExUnit.Case
  doctest DistTest

  test "greets the world" do
    assert DistTest.hello() == :world
  end
end
