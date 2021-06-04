defmodule Pobcoin.Consumer do
  use Nostrum.Consumer

  alias Nostrum.Api

  def start_link do
    Consumer.start_link(__MODULE__)
  end

  def handle_event({:MESSAGE_CREATE, message, _ws_state}) do


    if message.content == "!pob", do: Api.create_message(message.channel_id, "pob")
    if Enum.random(1..80) == 1, do: Api.create_reaction(message.channel_id, message.id, Enum.random(["thonk:381325006761754625", "🤔", "😂", "😭"]))
  end

  # Default event handler, if you don't include this, your consumer WILL crash if
  # you don't have a method definition for each event type.
  def handle_event(_event) do
    :noop
  end
end
