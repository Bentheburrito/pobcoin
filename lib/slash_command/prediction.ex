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
          description: "The prediction prompt (e.g. will Pob play among us today?)",
          required: true
        },
        %{
          # ApplicationCommandType::STRING
          type: 3,
          name: "outcome_1",
          description: "The first possible outcome for the prediction (80 character max).",
          required: true
        },
        %{
          # ApplicationCommandType::STRING
          type: 3,
          name: "outcome_2",
          description: "The second possible outcome for the prediction (80 character max).",
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
  def ephemeral?, do: true

  @impl SlashCommand
  def run(%Interaction{id: id, token: token} = interaction) do
    %{
      "prompt" => prompt,
      "outcome_1" => outcome_1,
      "outcome_2" => outcome_2,
      "submission_period" => sub_period
    } = SlashCommand.get_options(interaction)

    # TODO: Instead warn the user that a supplied outcome is over 80 characters
    outcome_1 = outcome_1 |> to_string() |> String.slice(0..79)
    outcome_2 = outcome_2 |> to_string() |> String.slice(0..79)

    outcomes = %{outcome_1 => %{}, outcome_2 => %{}}
    embed = create_prediction_embed(prompt, outcomes)
    components = create_prediction_components(id, outcomes)

    message =
      Nostrum.Api.create_message!(interaction.channel_id,
        components: components,
        embeds: [embed],
        content: "#{interaction.user.username} has started a prediction!"
      )

    Pobcoin.PredictionHandler.new(
      id,
      {interaction.channel_id, message.id},
      prompt,
      outcome_1,
      outcome_2,
      sub_period,
      interaction.user.id
    )

    prediction_management_components = [
      %{
        "type" => 1,
        "components" => [
          %{
            "type" => 2,
            "label" => outcome_1,
            # (disable_close_button &&
            #   "Prediction Closed") ||
            #  "Close Prediction (prediction creator only)",
            "style" => 3,
            "custom_id" => "close:#{Utils.hash_outcome_label(outcome_1)}:#{id}",
            # disable_close_button
            "disabled" => false
          },
          %{
            "type" => 2,
            "label" => outcome_2,
            # (disable_close_button &&
            #   "Prediction Closed") ||
            #  "Close Prediction (prediction creator only)",
            "style" => 3,
            "custom_id" => "close:#{Utils.hash_outcome_label(outcome_2)}:#{id}",
            # disable_close_button
            "disabled" => false
          }
        ]
      }
    ]

    {:response,
     [
       components: prediction_management_components,
       content: """
       You started a prediction!
       When it's time to decide a winning outcome, click one of the buttons below to close the prediction!
       """
     ]}

    # {:response, [components: components, embeds: [embed]]}
  end

  def create_prediction_components(
        id,
        outcomes,
        disable_wager_buttons \\ false,
        disable_close_button \\ false
      ) do
    [
      %{
        "type" => 1,
        "components" => [
          %{
            "type" => 3,
            "custom_id" => "pobcoin_selector:#{id}",
            "disabled" => disable_wager_buttons,
            "options" =>
              Enum.map([0, 1, 5, 10, 25, 50, 100], fn amount ->
                %{
                  "label" => "#{amount}",
                  "value" => amount,
                  "description" => "Wager #{amount} Pobcoin on your prediction.",
                  "emoji" => %{
                    "name" => "pobcoin",
                    "id" => "850900816826073099"
                  }
                }
              end),
            "placeholder" => "Select any Pobcoin you want to wager"
          }
        ]
      },
      %{
        "type" => 1,
        "components" =>
          Enum.map(outcomes, fn {label, _votes} ->
            %{
              "type" => 2,
              "label" => label,
              "style" => 1,
              "custom_id" => "#{Utils.hash_outcome_label(label)}:#{id}",
              "disabled" => disable_wager_buttons
            }
          end)
      }
    ]
  end

  def create_prediction_embed(prompt, outcomes) do
    %Embed{}
    |> Embed.put_title(prompt)
    |> Embed.put_description("Predict an outcome below!")
    |> Embed.put_color(Pobcoin.pob_purple())
    |> Embed.put_thumbnail(Pobcoin.pob_dollar_image_url())
    |> Embed.put_footer("Check your current balance of pobcoin with /pobcoin")
    |> then(fn embed ->
      Enum.reduce(outcomes, embed, fn {label, votes}, embed ->
        Embed.put_field(embed, label, create_outcome_info(votes), true)
      end)
    end)
  end

  defp create_outcome_info(outcome_votes) do
    total_wagered =
      outcome_votes
      |> Map.values()
      |> Enum.sum()

    """
    Users predicting: #{map_size(outcome_votes)}
    Pobcoin wagered: #{total_wagered}
    """
  end
end
