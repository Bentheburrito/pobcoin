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
          name: "outcome_1",
          description: "The first possible outcome for the prediction.",
          required: true
        },
        %{
          # ApplicationCommandType::STRING
          type: 3,
          name: "outcome_2",
          description: "The second possible outcome for the prediction.",
          required: true
        },
        %{
          # ApplicationCommandType::INTEGER
          type: 4,
          name: "submission_period",
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
      "outcome_1" => outcome_1,
      "outcome_2" => outcome_2,
      "submission_period" => sub_period
    } = SlashCommand.get_options(interaction)

    components = [%{
      "type" => 1,
      "components" => [%{
        "type" => 3,
        "custom_id" => "pobcoin_selector",
        "options" => Enum.map([0, 1, 5, 10, 25, 50, 100], fn amount ->
          %{
            "label" => "#{amount}",
            "value" => amount,
            "description" => "Wager #{amount} Pobcoin on your prediction.",
            "emoji" => %{
              "name" => "pobcoin",
              "id" => "850900816826073099",
            }
          }
        end),
        "placeholder" => "Select any Pobcoin you want to wager"
      }],
    }, %{
      "type" => 1,
      "components" => [%{
        "type" => 2,
        "label" => outcome_1,
        "style" => 1,
        "custom_id" => "outcome_1"
      },
      %{
        "type" => 2,
        "label" => outcome_2,
        "style" => 1,
        "custom_id" => "outcome_2"
      }]
    }]

    embed =
      %Embed{}
      |> Embed.put_author(
        interaction.member.user.username,
        nil,
        Nostrum.Struct.User.avatar_url(interaction.member.user)
      )
      |> Embed.put_title(prompt)
      |> Embed.put_description("Predict an outcome below!")
      |> Embed.put_field(outcome_1, create_outcome_stats(%{}), true)
      |> Embed.put_field(outcome_2, create_outcome_stats(%{}), true)
      |> Embed.put_color(Pobcoin.pob_purple())
      |> Embed.put_thumbnail(Pobcoin.pob_dollar_image_url())

    Pobcoin.Prediction.new(prompt, "outcome_1", "outcome_2")
    Task.start(fn ->
      Process.sleep(sub_period * 60 * 1000)
      # Edit discord message to disable buttons
      Pobcoin.Prediction.close_submissions(prompt)
    end)

    {:response, [components: components, embeds: [embed]]}
  end

  defp create_outcome_stats(outcome_stats) do
    {total_wagered, total_participants} =
      Enum.reduce(outcome_stats, {0, 0}, fn {_user_id, wager}, {cur_wagered, cur_participants} ->
        {cur_wagered + wager, cur_participants + 1}
      end)
    """
    Users predicting: #{total_participants}
    Pobcoin wagered: #{total_wagered}
    """
  end
end
