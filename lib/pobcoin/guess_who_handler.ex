defmodule Pobcoin.GuessWhoHandler do
  use Agent

  def start_link(_initial_value) do
    Agent.start_link(fn -> %{} end, name: __MODULE__)
  end

  def pop_guesses(channel_id) do
    Agent.get_and_update(__MODULE__, &Map.pop(&1, channel_id))
  end

  def init_game(channel_id) do
    Agent.get_and_update(__MODULE__, fn
      %{^channel_id => _guesses} = games -> {:game_in_progress, games}
      games -> {:ok, Map.put(games, channel_id, %{})}
    end)

    # &Map.put(&1, channel_id, %{}))
  end

  def put_guess(channel_id, guesser_id, guessee_id) do
    Agent.update(
      __MODULE__,
      fn
        %{^channel_id => guesses} = games ->
          new_guesses = Map.put(guesses, guesser_id, guessee_id)
          Map.put(games, channel_id, new_guesses)

        state ->
          state
      end
    )
  end
end
