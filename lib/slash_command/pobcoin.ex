defmodule SlashCommand.Pobcoin do
  require Logger

  alias Nostrum.Struct.{Interaction, Embed}

  @behaviour SlashCommand

  @impl SlashCommand
  def command_definition() do
    %{
      name: "pobcoin",
      description: "View your or another user's Pobcoin balance.",
      options: [
        %{
          # ApplicationCommandType::USER
          type: 6,
          name: "user",
          description: "User to check balance of (defaults to you).",
          required: false
        }
      ]
    }
  end

  @impl SlashCommand
  def command_scope() do
    {:guild, 381258048527794197}
  end

  @impl SlashCommand
  def ephemeral?, do: true

  @impl SlashCommand
  def run(%Interaction{} = interaction) do
    user_id =
      interaction
      |> SlashCommand.get_options()
      |> Map.get("user", interaction.member.user.id)

    user = Utils.get_or_new(user_id)
    with {:ok, %Nostrum.Struct.User{} = discord_user} <- Nostrum.Api.get_user(user_id) do
      embed =
        %Embed{}
        |> Embed.put_author(discord_user.username, nil, Nostrum.Struct.User.avatar_url(discord_user))
        |> Embed.put_field("Pobcoin Balance", user.coins, true)
        |> Embed.put_field("Status", "Very Poor | 1%-er", true)
        |> Embed.put_color(Pobcoin.pob_purple())
        |> Embed.put_image(Pobcoin.pob_dollar_image_url())

        {:embed, embed}
      else
        _ -> {:message, "Unable to retrieve user"}
    end
  end
end
