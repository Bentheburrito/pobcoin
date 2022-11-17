defmodule Pobcoin.GuessWhoHandler do
  use Agent

  def start_link(_initial_value) do
    Agent.start_link(fn -> %{} end, name: __MODULE__)
  end

  def pop_guesses(interaction_id) do
    Agent.get_and_update(__MODULE__, &Map.pop(&1, interaction_id))
  end

  def init_game(interaction_id) do
    Agent.update(__MODULE__, &Map.put(&1, interaction_id, %{}))
  end

  def put_guess(interaction_id, guesser_id, guessee_id) do
    Agent.update(
      __MODULE__,
      fn
        %{^interaction_id => guesses} = games ->
          new_guesses = Map.put(guesses, guesser_id, guessee_id)
          Map.put(games, interaction_id, new_guesses)

        state ->
          state
      end
    )
  end
end
