defmodule Pobcoin.Consumer do
  use Nostrum.Consumer

  alias Nostrum.Api

  require Logger

  @react_emojis [
    "pobcoin:850900816826073099",
    "thonk:381325006761754625",
    "🤔",
    "😂",
    "😭",
    "🇼",
    "🇱",
    "deezfingersupyournostrils:935231262313054258",
    "FallGuy2:870273932232650772"
  ]

  def start_link do
    Consumer.start_link(__MODULE__)
  end

  def handle_event({:MESSAGE_CREATE, message, _ws_state}) do
    if message.content == "!pob", do: Api.create_message(message.channel_id, "pob")

    if message.content == "!pobisdead",
      do: Api.create_message(message.channel_id, "Long Live Pob")

    if message.content == "!info",
      do:
        Api.create_message(message.channel_id, """
        I am a bot made by @Snowful#1234 for da best cousins in the world.
        My GitHub repository: https://github.com/Bentheburrito/pobcoin/
        """)

    if String.starts_with?(message.content, "!say ") and
         message.author.id in Application.get_env(:pobcoin, :oligarchs, []) do
      [_say, channel_id | message_list] = String.split(message.content)
      Api.create_message!(String.to_integer(channel_id), Enum.join(message_list, " "))
    end

    if Enum.random(1..Application.get_env(:pobcoin, :react_chance, 80)) == 1 do
      emoji = Enum.random(@react_emojis)
      Api.create_reaction(message.channel_id, message.id, emoji)
    end
  end

  def handle_event({:INTERACTION_CREATE, interaction, _ws_state}) do
    Pobcoin.InteractionHandler.handle_interaction(interaction)
  end

  def handle_event({:READY, data, _ws_state}) do
    Logger.info("Logged in under user #{data.user.username}##{data.user.discriminator}")
    Api.update_status(:dnd, "twitch.tv/pobsterlot", 3)

    # only automatically subscribe if we are in prod
    if System.get_env("MIX_ENV", "dev") == "prod" do
      Pobcoin.Twitch.init_eventsub_subscriptions()
    end

    SlashCommand.init_commands()
  end

  def handle_event({event, reg_ack, _ws_state})
      when event in [:APPLICATION_COMMAND_CREATE, :APPLICATION_COMMAND_UPDATE] do
    SlashCommand.put_register(reg_ack.name, reg_ack)
  end

  def handle_event(_event) do
    :noop
  end
end
