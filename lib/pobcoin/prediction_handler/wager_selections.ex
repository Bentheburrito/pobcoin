defmodule Pobcoin.PredictionHandler.WagerSelections do
  use Agent

  alias Pobcoin.{Repo, User}

  def start_link(_opts) do
    Agent.start_link(fn -> %{} end, name: __MODULE__)
  end

  def put_selection(id, wager) do
    case Repo.get(User, id) do
      nil ->
        :user_not_found

      %User{coins: coins} when coins >= wager ->
        Agent.update(__MODULE__, fn wagers -> Map.put(wagers, id, wager) end)

      _ ->
        :not_enough_coins
    end
  end

  def get_selection(id) do
    Agent.get(__MODULE__, fn wagers -> Map.get(wagers, id, 0) end)
  end
end
