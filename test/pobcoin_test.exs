defmodule PobcoinTest do
  use ExUnit.Case
  doctest Pobcoin

  test "greets the world" do
    assert Pobcoin.hello() == :world
  end
end
