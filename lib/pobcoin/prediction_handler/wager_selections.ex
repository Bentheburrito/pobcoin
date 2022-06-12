defmodule Pobcoin.PredictionHandler.WagerSelections do
  use Agent

  def start_link(_opts) do
    Agent.start_link(fn -> %{} end, name: __MODULE__)
  end

  def put_selection(id, wager) do
    Agent.update(__MODULE__, fn wagers -> Map.put(wagers, id, wager) end)
  end

  def get_selection(id) do
    Agent.get(__MODULE__, fn wagers -> Map.get(wagers, id, 0) end)
  end
end