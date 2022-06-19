defmodule Pobcoin.PredictionHandler.WagerSelections do
  use Agent

  alias Pobcoin.User

  require Logger

  def start_link(_opts) do
    Agent.start_link(fn -> %{} end, name: __MODULE__)
  end

  def put_selection({prediction_id, user_id} = id, wager) do
    total_wagered =
      get_total_wagered(user_id, prediction_id) +
        Pobcoin.PredictionHandler.get_users_wagered(user_id)

    case Utils.get_or_new(user_id) do
      %User{coins: coins} when coins >= wager + total_wagered ->
        Logger.info("Putting #{wager} under #{inspect(id)}")
        Agent.update(__MODULE__, fn wagers -> Map.put(wagers, id, wager) end)

      _ ->
        Agent.update(__MODULE__, fn wagers -> Map.delete(wagers, id) end)
        :not_enough_coins
    end
  end

  def get_selection(id) do
    Agent.get(__MODULE__, fn wagers -> Map.fetch(wagers, id) end)
  end

  def delete_selection(id) do
    Agent.update(__MODULE__, fn wagers -> Map.delete(wagers, id) end)
  end

  def get_total_wagered(user_id, excluding_prediction_id \\ nil) do
    Agent.get(__MODULE__, fn wagers ->
      for {{pred_id, ^user_id}, wager} <- wagers, pred_id != excluding_prediction_id, reduce: 0 do
        total_wagered -> total_wagered + wager
      end
    end)
  end

  def clear_for(prediction_id) do
    Agent.update(
      __MODULE__,
      &for {pred_id, user_id} when pred_id != prediction_id <- &1, into: %{} do
        {pred_id, user_id}
      end
    )
  end
end
