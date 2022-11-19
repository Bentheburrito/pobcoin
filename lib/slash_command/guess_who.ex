defmodule SlashCommand.GuessWho do
  alias Nostrum.Struct.{Embed, Interaction}
  alias Pobcoin.{GuessWhoEntry, Repo, User}

  import Ecto.Query

  require Logger

  @random_entry_query from(e in GuessWhoEntry,
                        where: is_nil(e.last_used_at),
                        order_by: fragment("RANDOM()"),
                        limit: 1
                      )

  # Once we've run out of unused entries, we'll use the least-recently used entry
  @lru_entry_query from(e in Pobcoin.GuessWhoEntry,
                     where: not is_nil(e.last_used_at),
                     order_by: e.last_used_at,
                     limit: 1
                   )

  @behaviour SlashCommand

  @impl SlashCommand
  def command_definition() do
    %{
      name: "guesswho",
      description: "Try to guess who sent a message from the cousin-curated list."
    }
  end

  @impl SlashCommand
  def command_scope() do
    {:guild, Application.get_env(:pobcoin, :guilds, [])}
  end

  @impl SlashCommand
  def ephemeral?, do: false

  @impl SlashCommand
  def run(%Interaction{} = interaction) do
    with nil <- Repo.one(@random_entry_query),
         nil <- Repo.one(@lru_entry_query) do
      {:response,
       content: "uh oh, I couldn't find an entry for Guess Who (@snowful wtf did you do idiot)"}
    else
      %GuessWhoEntry{} = entry ->
        start_game_with_entry(interaction, entry)
    end
  end

  defp start_game_with_entry(interaction, entry) do
    submitter = entry.submitter_id |> Nostrum.Api.get_user() |> elem(1)

    embed =
      %Embed{}
      |> Embed.put_author(
        "Who am I?",
        nil,
        "https://cdn.discordapp.com/attachments/381258231613227020/1043282961929347163/image.png"
      )
      |> Embed.put_description(entry.message_text)
      |> Embed.put_field(
        "Guess who sent the above message to win 10 <:pobcoin:850900816826073099>",
        "Guessing will end in __90 seconds!__"
      )
      |> Embed.put_color(Pobcoin.pob_purple())
      |> Embed.put_footer(
        "Submitted by #{submitter.username}",
        Nostrum.Struct.User.avatar_url(submitter)
      )

    guess_user_components = [
      %{
        "type" => 1,
        "components" => [
          %{
            "type" => 5,
            "label" => "Who sent the message?",
            "style" => 3,
            "custom_id" => "guess:#{interaction.id}:#{entry.submitter_id}",
            "disabled" => false
          }
        ]
      }
    ]

    case Pobcoin.GuessWhoHandler.init_game(interaction.channel_id) do
      :game_in_progress ->
        {:response, content: "There's already a game in this channel! I eat poop."}

      :ok ->
        Task.start(fn -> start_game_then_end_after(interaction, entry, 1000 * 90) end)

        {:response, [embeds: [embed], components: guess_user_components]}
    end
  end

  defp start_game_then_end_after(
         %Interaction{} = interaction,
         %GuessWhoEntry{correct_answer_id: cai} = entry,
         timeout_ms
       ) do
    entry_cs = GuessWhoEntry.changeset(entry, %{"last_used_at" => DateTime.utc_now()})
    Repo.update!(entry_cs)

    Process.sleep(timeout_ms)

    guesses = Pobcoin.GuessWhoHandler.pop_guesses(interaction.channel_id)

    correct_guessers =
      for {guesser_id, ^cai} <- guesses do
        guesser_id
      end

    winners = Enum.map_join(correct_guessers, ", ", &Nostrum.Api.get_user!/1)

    case Nostrum.Api.get_user(cai) do
      {:ok, user} ->
        # NOTE: this message link will break if Pobcoin is ever added to other guilds. If messages are added from one
        # guilds and the game uses them in a game in another guild, the link MIGHT still work if the user that clicks
        # it is in both guilds. To fix this you could add a `guild_id` field to the %GuessWhoEntry{} schema
        embed =
          %Embed{}
          |> Embed.put_author(
            user.username,
            "https://discord.com/channels/#{interaction.guild_id}/#{entry.channel_id}/#{entry.message_id}",
            Nostrum.Struct.User.avatar_url(user)
          )
          |> Embed.put_description(entry.message_text)
          |> Embed.put_field(
            "Winners (+10 <:pobcoin:850900816826073099> each)",
            (winners == "" && "Nobody :(") || winners
          )
          |> Embed.put_color((winners == "" && Pobcoin.error_red()) || Pobcoin.good_green())

        Nostrum.Api.create_message(interaction.channel_id,
          content: "**Guessing is over**",
          embeds: [embed]
        )

        # Not going to use a Multi here, since still we want others to receive their reward if some fail.
        Enum.each(correct_guessers, fn guesser_id ->
          user = Utils.get_or_new(guesser_id)

          user
          |> User.changeset(%{"coins" => user.coins + 10})
          |> Repo.update()
          |> case do
            {:ok, _struct} ->
              nil

            {:error, reason} ->
              Logger.warning(
                "Couldn't give 10 pobcoin reward to #{user.user_id}: #{inspect(reason)}"
              )
          end
        end)

      {:error, reason} ->
        Logger.error("Couldn't get correct answer user ID: #{inspect(reason)}")

        Nostrum.Api.create_message(
          interaction.channel_id,
          "Uh oh, I couldn't get the author of that message - blame snow :/"
        )
    end
  end
end
