defmodule Pobcoin.Consumer do
  use Nostrum.Consumer

  alias Nostrum.Api
  alias Pobcoin.{User, Repo}
  alias Ecto.Multi

  require Logger

  @react_emojis [
    "pobcoin:850900816826073099",
    "thonk:381325006761754625",
    "🤔",
    "😂",
    "😭",
    "🇼",
    "🇱",
    "deezfingersupyournostrils:935231262313054258"
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
    IO.puts("Logged in under user #{data.user.username}##{data.user.discriminator}")
    Api.update_status(:dnd, "twitch.tv/pobsterlot", 3)

    # only automatically subscribe if we are in prod
    if System.get_env("MIX_ENV", "dev") == "prod" do
      Pobcoin.Twitch.init_eventsub_subscriptions()
    end

    Task.start(&decrement_blood/0)

    SlashCommand.init_commands()
  end

  def handle_event({event, reg_ack, _ws_state})
      when event in [:APPLICATION_COMMAND_CREATE, :APPLICATION_COMMAND_UPDATE] do
    SlashCommand.put_register(reg_ack.name, reg_ack)
  end

  def handle_event(_event) do
    :noop
  end

  defp decrement_blood() do
    Process.sleep(1000 * 60 * 60)

    %User{} = users = Repo.all(User)

    {multi, died} =
      for user <- users, user.blood != 0, reduce: {Multi.new(), []} do
        {multi, died} ->
          cs = User.changeset(user, %{"blood" => user.blood - 1})
          died = if user.blood - 1 == 0, do: [user.user_id | died], else: died
          {Multi.update(multi, "user_#{user.user_id}", cs), died}
      end

    case Repo.transaction(multi) do
      {:ok, _map} ->
        Api.create_message(381_258_231_613_227_020, "Everyone's health has decreased by 1!")

        dead_usernames =
          Enum.map_join(died, "\n- ", fn user_id ->
            case Nostrum.Cache.UserCache.get(user_id) do
              {:ok, user} -> user.username
              {:error, _} -> "unknown username (ID #{user_id}"
            end
          end)

        Api.create_message(381_258_231_613_227_020, """
        Unfortunately, some vampires have passed away...
        - #{dead_usernames}
        """)

      {:error, fail_op, fail_val, _} ->
        Logger.error(
          "ERROR SUBTRACTING BLOOD #{inspect(fail_op, label: "fail op")} #{inspect(fail_val, label: "fail val")}"
        )
    end

    decrement_blood()
  end
end
