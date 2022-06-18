defmodule Pobcoin.PredictionHandler do
  use GenServer

  ## API
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def new(prediction_id, token, prompt, outcome_1, outcome_2, submission_period, owner_id) do
    IO.inspect("ASBOUT TO DO NEW PREDICTION IN PREDICTION HANDLER")

    GenServer.call(
      __MODULE__,
      {:new, prediction_id, token, prompt, outcome_1, outcome_2, submission_period, owner_id}
    )
  end

  def predict(prediction_id, outcome, user_id, wager) do
    GenServer.call(__MODULE__, {:predict, prediction_id, outcome, user_id, wager})
  end

  def close(prediction_id, user_id) do
    GenServer.call(__MODULE__, {:close, prediction_id, user_id})
  end

  @spec get(Nostrum.Snowflake.t()) :: {:ok, prediction :: map()} | :error
  def get(prediction_id) do
    GenServer.call(__MODULE__, {:get, prediction_id})
  end

  ## Impl
  def init(predictions) do
    {:ok, predictions}
  end

  def handle_call(
        {:new, id, token, prompt, outcome_1, outcome_2, submission_period, owner_id},
        _from,
        predictions
      ) do
    init_prediction = %{
      outcomes: %{outcome_1 => %{}, outcome_2 => %{}},
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
    prediction = Map.get(predictions, id, %{outcomes: %{}})

    cond do
      user_predicted_diff_outcome?(user_id, outcome, prediction) ->
        {:reply, :already_predicted_diff_outcome, predictions}

      prediction[:can_predict] == false ->
        {:reply, :submissions_closed, predictions}

      true ->
        new_predictions =
          Utils.update_in(predictions, [id, :outcomes, outcome, user_id], wager, &(&1 + wager))
          |> IO.inspect(label: "NEW_PREDICTIONS")

        {:reply, {:ok, new_predictions[id]}, new_predictions}
    end
    |> IO.inspect(label: "result of PredictionHandler.predict()")
  end

  def handle_call({:close, id, user_id}, _from, predictions) do
    {closed, new_predictions} = Map.pop(predictions, id, %{owner_id: nil})

    if user_id != closed.owner_id do
      {:reply, :unauthorized, predictions}
    else
      {:reply, {id, closed}, new_predictions}
    end
  end

  def handle_call({:get, id}, _from, predictions) do
    {:reply, Map.fetch(predictions, id), predictions}
  end

  def handle_info({:close_submissions, id, token}, predictions) do
    case Map.fetch(predictions, id) do
      {:ok, prediction} ->
        embed =
          SlashCommand.Prediction.create_prediction_embed(prediction.prompt, prediction.outcomes)

        components =
          SlashCommand.Prediction.create_prediction_components(id, prediction.outcomes, true)

        Nostrum.Api.edit_interaction_response(token, %{embeds: [embed], components: components})

        new_predictions =
          Map.update!(predictions, id, fn prediction ->
            %{prediction | can_predict: false}
          end)

        {:noreply, new_predictions}

      _ ->
        {:noreply, predictions}
    end
  end

  defp user_predicted_diff_outcome?(user_id, newly_guessed_outcome, prediction) do
    Map.get(prediction, :outcomes, %{})
    |> Map.delete(newly_guessed_outcome)
    |> Enum.any?(fn
      {_outcome, votes} when is_map(votes) ->
        # User has predicted this outcome
        Map.has_key?(votes, user_id)

      _ ->
        false
    end)
  end
end
