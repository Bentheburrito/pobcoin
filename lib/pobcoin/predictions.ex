defmodule Pobcoin.Prediction do
  use GenServer

  ## API
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, [name: __MODULE__])
  end

  def new(prompt, outcome_1, outcome_2) do
    GenServer.call(__MODULE__, {:new, prompt, outcome_1, outcome_2})
  end

  def predict(prompt, outcome, user_id, wager) do
    GenServer.call(__MODULE__, {:predict, prompt, outcome, user_id, wager})
  end

  def close_submissions(prompt) do
    GenServer.call(__MODULE__, {:close_submissions, prompt})
  end

  def close(prompt) do
    GenServer.call(__MODULE__, {:close, prompt})
  end

  ## Impl
  def init(predictions) do
    {:ok, predictions}
  end

  def handle_call({:new, prompt, _outcome_1, _outcome_2}, _from, predictions) when is_map_key(predictions, prompt) do
    {:reply, :already_a_prediction, predictions}
  end

  def handle_call({:new, prompt, outcome_1, outcome_2}, _from, predictions) do
    {:reply, :ok, Map.put(predictions, prompt, %{outcome_1 => %{}, outcome_2 => %{}, can_predict: true}), predictions}
  end

  def handle_call({:predict, prompt, outcome, user_id, wager}, _from, predictions) do
    prediction = Map.get(predictions, prompt)
    cond do
      user_predicted_diff_outcome?(user_id, outcome, prediction) ->
        {:reply, :already_predicted_diff_outcome, predictions}

      not prediction.can_predict ->
        {:reply, :submissions_closed, predictions}

      true ->
        new_predictions = Map.update!(predictions, prompt, fn %{^outcome => old_outcome} = prediction ->
          %{prediction | outcome => Map.update(old_outcome, user_id, wager, &(&1 + wager))}
        end)

        {:reply, :ok, new_predictions}
    end
  end

  def handle_call({:close_submissions, prompt}, _from, predictions) do
    # update_if_exists
    new_predictions =
      Map.has_key?(predictions, prompt)
      && Map.update!(predictions, prompt, fn prediction ->
        %{prediction | can_predict: false}
      end)
      || predictions

    {:reply, :ok, new_predictions}
  end

  def handle_call({:close, prompt}, _from, predictions) do
    {closed, new_predictions} = Map.pop(predictions, prompt, :none)
    {:reply, closed, new_predictions}
  end

  defp user_predicted_diff_outcome?(user_id, newly_guessed_outcome, prediction) do
    prediction
    |> Map.delete(newly_guessed_outcome)
    |> Enum.any?(fn outcome ->
      Map.get(outcome, user_id) != nil # User has predicted this outcome
    end)
  end
end
