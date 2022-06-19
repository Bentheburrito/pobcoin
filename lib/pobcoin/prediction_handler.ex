defmodule Pobcoin.PredictionHandler do
  use GenServer

  ## API
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def new(prediction_id, token, prompt, outcome_1, outcome_2, submission_period, owner_id) do
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

  def get_users_wagered(user_id) do
    GenServer.call(__MODULE__, {:users_wagered, user_id})
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
      owner_id: owner_id,
      label_map: %{
        Utils.hash_outcome_label(outcome_1) => {outcome_1, outcome_2},
        Utils.hash_outcome_label(outcome_2) => {outcome_2, outcome_1}
      }
    }

    Process.send_after(self(), {:close_submissions, id, token}, submission_period * 60 * 1000)

    {:reply, :ok, Map.put(predictions, id, init_prediction)}
  end

  def handle_call({:predict, id, {:hashed_label, hash}, user_id, wager}, from, predictions) do
    {outcome_label, _} = Map.get(predictions[id].label_map, hash)
    handle_call({:predict, id, outcome_label, user_id, wager}, from, predictions)
  end

  def handle_call({:predict, id, outcome, user_id, wager}, _from, predictions) do
    prediction = Map.get(predictions, id, %{outcomes: %{}})
    Pobcoin.PredictionHandler.WagerSelections.delete_selection({id, user_id})

    cond do
      user_predicted_diff_outcome?(user_id, outcome, prediction) ->
        {:reply, :already_predicted_diff_outcome, predictions}

      prediction[:can_predict] == false ->
        {:reply, :submissions_closed, predictions}

      true ->
        new_predictions =
          Utils.update_in(predictions, [id, :outcomes, outcome, user_id], wager, &(&1 + wager))

        {:reply, {:ok, new_predictions[id]}, new_predictions}
    end
  end

  def handle_call({:close, id, _user_id}, _from, predictions) do
    {closed, new_predictions} = Map.pop(predictions, id, :not_found)

    if closed == :not_found do
      {:reply, :not_found, predictions}
    else
      Pobcoin.PredictionHandler.WagerSelections.clear_for(id)
      Pobcoin.determine_one_percenters()
      {:reply, {id, closed}, new_predictions}
    end
  end

  def handle_call({:get, id}, _from, predictions) do
    {:reply, Map.fetch(predictions, id), predictions}
  end

  def handle_call({:users_wagered, user_id}, _from, predictions) do
    total_wagered =
      Enum.reduce(predictions, 0, fn {_id, prediction}, total_wagered ->
        Stream.map(prediction.outcomes, &Map.get(elem(&1, 1), user_id, 0))
        |> Enum.sum()
        |> Kernel.+(total_wagered)
      end)

    {:reply, total_wagered, predictions}
  end

  def handle_info({:close_submissions, id, _token}, predictions) do
    case Map.fetch(predictions, id) do
      {:ok, prediction} ->
        embed =
          SlashCommand.Prediction.create_prediction_embed(prediction.prompt, prediction.outcomes)

        components =
          SlashCommand.Prediction.create_prediction_components(id, prediction.outcomes, true)

        {channel_id, message_id} = prediction.token

        Nostrum.Api.edit_message(channel_id, message_id, %{
          embeds: [embed],
          components: components
        })

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
