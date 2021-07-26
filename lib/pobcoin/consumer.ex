defmodule Pobcoin.Consumer do
  use Nostrum.Consumer

  alias Nostrum.Api

  def start_link do
    Consumer.start_link(__MODULE__)
  end

  def handle_event({:MESSAGE_CREATE, message, _ws_state}) do
    if message.content == "!pob", do: Api.create_message(message.channel_id, "pob")
    if String.starts_with?(message.content, "!say ") and message.author.id in Application.get_env(:pobcoin, :oligarchs, []) do
      [_say, channel_id | message_list] = String.split(message.content)
      Api.create_message!(String.to_integer(channel_id), Enum.join(message_list, " "))
    end

    if Enum.random(1..80) == 1 do
      emoji = Enum.random(["pobcoin:850900816826073099", "thonk:381325006761754625", "🤔", "😂", "😭"])
      Api.create_reaction(message.channel_id, message.id, emoji)
    end
  end

  def handle_event({:INTERACTION_CREATE, interaction, _ws_state}) do
    Pobcoin.InteractionHandler.handle_interaction(interaction)
  end

  def handle_event({:READY, data, _ws_state}) do
		IO.puts("Logged in under user #{data.user.username}##{data.user.discriminator}")
		Api.update_status(:dnd, "twitch.tv/pobsterlot", 3)

    SlashCommand.init_commands()
	end

  def handle_event({event, reg_ack, _ws_state}) when event in [:APPLICATION_COMMAND_CREATE, :APPLICATION_COMMAND_UPDATE] do
    SlashCommand.put_register(reg_ack.name, reg_ack)
  end

  # Default event handler, if you don't include this, your consumer WILL crash if
  # you don't have a method definition for each event type.
  def handle_event(_event) do
    :noop
  end
end
