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

    outcomes = %{outcome_1 => %{}, outcome_2 => %{}}
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
          Enum.map(outcomes, fn {label, _votes} ->
            %{
              "type" => 2,
              "label" => label,
              "style" => 1,
              "custom_id" => "#{label}:#{id}",
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
    |> then(fn embed ->
      Enum.reduce(outcomes, embed, fn {label, votes}, embed ->
        Embed.put_field(embed, label, create_outcome_info(votes), true)
      end)
    end)
  end

  @doc """
  tallies total votes, grouped by outcome. You can also tally the participants based on `participant_tally_type`

  - `:count`: Count each vote (not guaranteed to uniquely identify each participant).
  - `:ids`: Adds each voter's ID to a list (like with `:count`, the list could contain duplicate IDs).
  - `:none`: No tallying of participants, just the wager
  """
  @spec tally_outcome_votes(
          votes :: %{Nostrum.Snowflake.t() => integer()},
          participant_tally_type :: :ids | :count | :none
        ) :: {integer(), integer() | list()} | integer()
  def tally_outcome_votes(votes, participant_tally_type \\ :count)
      when participant_tally_type in [:ids, :count, :none] do
    init_acc =
      case participant_tally_type do
        :count -> {0, 0}
        :ids -> {0, []}
        :none -> 0
      end

    Enum.reduce(votes, init_acc, &tally_reducer/2)
  end

  defp tally_reducer({_user_id, wager}, acc) when not is_number(wager), do: acc

  defp tally_reducer({_user_id, wager}, {cur_wagered, participant_count})
       when is_integer(participant_count) do
    {cur_wagered + wager, participant_count + 1}
  end

  defp tally_reducer({user_id, wager}, {cur_wagered, participant_ids})
       when is_list(participant_ids) do
    {cur_wagered + wager, [user_id | participant_ids]}
  end

  defp tally_reducer({_user_id, wager}, cur_wagered) do
    cur_wagered + wager
  end

  defp create_outcome_info(outcome_votes) do
    {total_wagered, total_participants} = tally_outcome_votes(outcome_votes)

    """
    Users predicting: #{total_participants}
    Pobcoin wagered: #{total_wagered}
    """
  end
end
