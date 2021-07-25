defmodule SlashCommand.Prediction do
  require Logger

  alias Nostrum.Struct.{Interaction, Embed}

  @behaviour SlashCommand

  @impl SlashCommand
  def command_definition() do
    %{
      name: "prediction",
      description: "Start a prediction (Pob and mods only).",
      options: [
        %{
          # ApplicationCommandType::STRING
          type: 3,
          name: "prompt",
          description: "The prediction prompt (i.e. will Pob win the amongus?)",
          required: true
        },
        %{
          # ApplicationCommandType::STRING
          type: 3,
          name: "outcome 1",
          description: "The first outcome for the prediction.",
          required: true
        },
        %{
          # ApplicationCommandType::STRING
          type: 3,
          name: "outcome 2",
          description: "The second outcome for the prediction.",
          required: true
        },
        %{
          # ApplicationCommandType::INTEGER
          type: 4,
          name: "submission period",
          description: "The amount of time participants are allowed to predict (in minutes)",
          required: true
        }
      ]
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
    %{
      "prompt" => prompt,
      "outcome 1" => outcome_1,
      "outcome 2" => outcome_2,
      "submission period" => sub_period
    } = SlashCommand.get_options(interaction)

    embed =
      %Embed{}
      |> Embed.put_author(
        interaction.member.user.username,
        nil,
        Nostrum.Struct.User.avatar_url(interaction.member.user)
      )
      |> Embed.put_title("A Prediction has started")
      |> Embed.put_description(prompt)
      |> Embed.put_field(outcome_1)
      |> Embed.put_color(Pobcoin.pob_purple())
      |> Embed.put_image(Pobcoin.pob_dollar_image_url())

    {:embed, embed}
  end
end
