defmodule Buttons do
  alias Nostrum.Struct.Interaction
  alias Pobcoin.InteractionHandler
  alias Pobcoin.PredictionHandler.WagerSelections
  alias Pobcoin.PredictionHandler

  require Logger

  def handle_interaction(%Interaction{data: %{custom_id: "pobcoin_selector:" <> prediction_id_str, values: [pobcoin_amount_str]}} = interaction) do
    user_id = interaction.member.user.id
    prediction_id = String.to_integer(prediction_id_str)

    WagerSelections.put_selection({prediction_id, user_id}, String.to_integer(pobcoin_amount_str))

    InteractionHandler.respond(interaction, [])
  end

  def handle_interaction(%Interaction{data: %{custom_id: <<outcome::binary-size(9)>> <> ":" <> prediction_id_str}} = interaction) do
    user_id = interaction.member.user.id
    prediction_id = String.to_integer(prediction_id_str)
    wager = WagerSelections.get_selection({prediction_id, user_id})

    with {:ok, prediction} <- PredictionHandler.predict(prediction_id, outcome, user_id, wager),
         outcomes_list <- Enum.filter(prediction, fn {_, stats} -> is_map(stats) and not is_struct(stats) end),
         outcomes <- Map.new(outcomes_list) do

      Logger.debug("#{interaction.member.user.username} predicted \"#{outcomes[outcome][:label]}\" with #{wager} Pobcoin")
      embed = SlashCommand.Prediction.create_prediction_embed(prediction.prompt, outcomes)

      IO.inspect(Nostrum.Api.edit_interaction_response(interaction, %{embeds: [embed]}))
      InteractionHandler.respond(interaction, [])
    else
      :submissions_closed ->
        InteractionHandler.respond(interaction, [content: "Sorry, submissions have closed for this prediction!"], true)
      :already_predicted_diff_outcome ->
        InteractionHandler.respond(interaction, [content: "You've already predicted a different outcome, haha"], true)
      e ->
        Logger.error("Something went wrong with a button press: Unknown response from PredictionHandler: #{inspect e}")
        InteractionHandler.respond(interaction, [content: "Uh oh, something went very wrong, please try again in a bit."], true)
    end
  end
end
