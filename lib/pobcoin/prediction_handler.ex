defmodule Pobcoin.PredictionHandler do
  use GenServer

  ## API
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, [name: __MODULE__])
  end

  def new(prediction_id, token, prompt, outcome_1, outcome_2, submission_period, owner_id) do
		IO.inspect "ASBOUT TO DO NEW PREDICTION IN PREDICTION HANDLER"
    GenServer.call(__MODULE__, {:new, prediction_id, token, prompt, outcome_1, outcome_2, submission_period, owner_id})
  end

  def predict(prediction_id, outcome, user_id, wager) do
    GenServer.call(__MODULE__, {:predict, prediction_id, outcome, user_id, wager})
  end

  def close(prediction_id, user_id) do
    GenServer.call(__MODULE__, {:close, prediction_id, user_id})
  end

  ## Impl
  def init(predictions) do
    {:ok, predictions}
  end

  def handle_call({:new, id, token, prompt, outcome_1, outcome_2, submission_period, owner_id}, _from, predictions) do
    init_prediction = %{
      "outcome_1" => %{label: outcome_1},
      "outcome_2" => %{label: outcome_2},
      prompt: prompt,
			token: token,
      can_predict: true,
      submissions_close: DateTime.add(DateTime.now!("Etc/UTC"), submission_period * 60, :second),
			owner_id: owner_id
    }
    Process.send_after(self(), {:close_submissions, id, token}, submission_period * 60 * 1000)

    {:reply, :ok, Map.put(predictions, id, init_prediction)}
  end

  def handle_call({:predict, id, outcome, user_id, wager}, _from, predictions) do
    prediction = Map.get(predictions, id, %{})
    cond do
      user_predicted_diff_outcome?(user_id, outcome, prediction) ->
        {:reply, :already_predicted_diff_outcome, predictions}

      prediction[:can_predict] == false ->
        {:reply, :submissions_closed, predictions}

      true ->
        new_predictions = Map.update!(predictions, id, fn %{^outcome => user_predictions} = prediction ->
          %{prediction | outcome => Map.update(user_predictions, user_id, wager, &(&1 + wager))}
        end)

        {:reply, {:ok, new_predictions[id]}, new_predictions}
    end |> IO.inspect(label: "result of PredictionHandler.predict()")
  end

  def handle_call({:close, id, user_id}, _from, predictions) do
    {closed, new_predictions} = Map.pop(predictions, id, %{owner_id: nil})
		if user_id != closed.owner_id do
			{:reply, :unauthorized, predictions}
		else
			{:reply, {id, closed}, new_predictions}
		end
  end

  def handle_info({:close_submissions, id, token}, predictions) do
    # update_if_exists
    new_predictions =
      Map.has_key?(predictions, id)
      && Map.update!(predictions, id, fn prediction ->
        %{prediction | can_predict: false}
      end)
      || predictions

    with {:ok, prediction} <- Map.fetch(predictions, id),
        outcomes_list <- Enum.filter(prediction, fn {_, stats} -> is_map(stats) and not is_struct(stats) end),
        outcomes <- Map.new(outcomes_list) do

      embed = SlashCommand.Prediction.create_prediction_embed(prediction.prompt, outcomes)
      components = SlashCommand.Prediction.create_prediction_components(id, outcomes, true)

      Nostrum.Api.edit_interaction_response(token, %{embeds: [embed], components: components})

      new_predictions =
        Map.update!(predictions, id, fn prediction ->
          %{prediction | can_predict: false}
        end)

      {:noreply, new_predictions}
    else
      _ -> {:noreply, predictions}
    end
  end

  defp user_predicted_diff_outcome?(user_id, newly_guessed_outcome, prediction) do
    prediction
    |> Map.delete(newly_guessed_outcome)
    |> Enum.any?(fn
      {_outcome, stats} when is_map(stats) ->
        Map.has_key?(stats, user_id) # User has predicted this outcome
      _ ->
        false
    end)
  end
end
