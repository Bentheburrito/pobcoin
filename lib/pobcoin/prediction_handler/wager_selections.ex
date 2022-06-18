defmodule Pobcoin.PredictionHandler.WagerSelections do
  use Agent

  alias Pobcoin.User

  require Logger

  def start_link(_opts) do
    Agent.start_link(fn -> %{} end, name: __MODULE__)
  end

  def put_selection({_prediction_id, user_id} = id, wager) do
    total_wagered = get_total_wagered(user_id)

    case Utils.get_or_new(user_id) do
      %User{coins: coins} when coins >= wager + total_wagered ->
        Logger.info("Putting #{wager} under #{inspect(id)}")
        Agent.update(__MODULE__, fn wagers -> Map.put(wagers, id, wager) end)

      _ ->
        :not_enough_coins
    end
  end

  def get_selection(id) do
    Agent.get(__MODULE__, fn wagers -> Map.fetch(wagers, id) end)
  end

  def get_total_wagered(user_id) do
    Agent.get(__MODULE__, fn wagers ->
      for {{_pred_id, ^user_id}, wager} <- wagers, reduce: 0 do
        total_wagered -> total_wagered + wager
      end
    end)
  end
end
