defmodule SlashCommand.AddGuessWhoEntry do
  require Logger

  alias Nostrum.Struct.Interaction
  alias Pobcoin.{GuessWhoEntry, Repo}

  @behaviour SlashCommand

  @impl SlashCommand
  def command_definition() do
    %{
      type: 3,
      name: "Add to 'Guess Who' list",
      description: ""
    }
  end

  @impl SlashCommand
  def command_scope() do
    {:guild, Application.get_env(:pobcoin, :guilds, [])}
  end

  @impl SlashCommand
  def ephemeral?, do: true

  @impl SlashCommand
  def run(%Interaction{} = interaction) do
    message =
      interaction.data.resolved.messages
      |> Enum.take(1)
      |> List.first()
      |> elem(1)

    case Nostrum.Api.get_guild_member(interaction.guild_id, message.author.id) do
      {:ok, _member} ->
        add_entry(interaction, message)

      {:error, error} ->
        Logger.info(
          "User tried to add a 'Guess Who' entry from a user who is no longer a guild member. Error: #{inspect(error)}"
        )

        {:response,
         content: "Unable to add that entry - did the author of the message leave the server?"}
    end
  end

  defp add_entry(interaction, message) do
    changeset =
      GuessWhoEntry.changeset(%GuessWhoEntry{}, %{
        "submitter_id" => interaction.user.id,
        "message_text" => message.content,
        "message_id" => message.id,
        "channel_id" => message.channel_id,
        "correct_answer_id" => message.author.id
      })

    case Repo.insert(changeset) do
      {:ok, _entry} ->
        {:response, content: "Successfully added your entry! ✅"}

      {:error, changeset} ->
        Logger.error("UNABLE TO ADD GUESS WHO ENTRY: #{inspect(changeset)}")

        {:response,
         content: "I wasn't able to add your entry, please ping @Snowful#1234's dumb ass"}
    end
  end
end
