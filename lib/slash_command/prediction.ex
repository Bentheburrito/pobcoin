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
  def ephemeral?, do: false

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

    outcomes = %{"outcome_1" => %{label: outcome_1}, "outcome_2" => %{label: outcome_2}}
    embed = create_prediction_embed(prompt, outcomes)
    components = create_prediction_components(id, outcomes)
    # create_prediction_message(id, prompt, outcomes, interaction.member.user)
    Pobcoin.PredictionHandler.new(
      id,
      token,
      prompt,
      outcome_1,
      outcome_2,
      sub_period,
      interaction.user.id
    )

    {:response, [components: components, embeds: [embed]]}
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
          Enum.map(outcomes, fn {outcome, %{label: label}} ->
            %{
              "type" => 2,
              "label" => label,
              "style" => 1,
              "custom_id" => "#{outcome}:#{id}",
              "disabled" => disable_wager_buttons
            }
          end) ++
            [
              %{
                "type" => 2,
                "label" =>
                  (disable_close_button &&
                     "Prediction Closed") ||
                    "Close Prediction (prediction creator only)",
                "style" => 3,
                "custom_id" => "close:#{id}",
                "disabled" => disable_close_button
              }
            ]
      }
    ]
  end

  def create_prediction_embed(prompt, outcomes) do
    %Embed{}
    |> Embed.put_title(prompt)
    |> Embed.put_description("Predict an outcome below!")
    |> Embed.put_color(Pobcoin.pob_purple())
    |> Embed.put_thumbnail(Pobcoin.pob_dollar_image_url())
    |> then(
      &Enum.reduce(outcomes, &1, fn {outcome, stats}, embed ->
        Embed.put_field(embed, outcome, create_outcome_info(stats), true)
      end)
    )
  end

  defp create_outcome_info(outcome_stats) do
    {total_wagered, total_participants} =
      Enum.reduce(outcome_stats, {0, 0}, fn {_user_id, wager},
                                            {cur_wagered, cur_participants} = acc ->
        if is_number(wager) do
          {cur_wagered + wager, cur_participants + 1}
        else
          acc
        end
      end)

    """
    Users predicting: #{total_participants}
    Pobcoin wagered: #{total_wagered}
    """
  end
end
