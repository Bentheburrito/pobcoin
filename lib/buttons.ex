defmodule Buttons do
  alias Ecto.Multi
  alias Nostrum.Struct.Interaction
  alias Pobcoin.InteractionHandler
  alias Pobcoin.PredictionHandler.WagerSelections
  alias Pobcoin.PredictionHandler

  require Logger

  def handle_interaction(
        %Interaction{
          data: %{
            custom_id: "pobcoin_selector:" <> prediction_id_str,
            values: [pobcoin_amount_str]
          }
        } = interaction
      ) do
    user_id = interaction.member.user.id
    prediction_id = String.to_integer(prediction_id_str)
    wager_id = {prediction_id, user_id}

    case WagerSelections.put_selection(wager_id, String.to_integer(pobcoin_amount_str)) do
      :not_enough_coins ->
        response = [content: "You don't have enough Pobcoin to wager that much!"]
        InteractionHandler.respond(interaction, response, true)

      :ok ->
        InteractionHandler.respond(interaction, [])
    end
  end

  def handle_interaction(
        %Interaction{data: %{custom_id: "close:" <> prediction_id_str}} = interaction
      ) do
    user_id = interaction.member.user.id
    prediction_id = String.to_integer(prediction_id_str)

    case PredictionHandler.close(prediction_id, user_id) do
      :unauthorized ->
        InteractionHandler.respond(
          interaction,
          [content: "You didn't create this prediction!"],
          true
        )

      {id, prediction} ->
        # update the embed

        embed =
          SlashCommand.Prediction.create_prediction_embed(
            "[CLOSED] " <> prediction.prompt,
            prediction.outcomes
          )

        components =
          SlashCommand.Prediction.create_prediction_components(
            id,
            prediction.outcomes,
            true,
            true
          )

        Nostrum.Api.edit_interaction_response(Nostrum.Cache.Me.get().id, prediction.token, %{
          embeds: [embed],
          components: components
        })

        # distribute pobcoin
        # wage_reducer = fn {user_id, wager}, {cur_wagered, participants} = acc ->
        #   if is_number(wager) do
        #     {cur_wagered + wager, Map.update(participants, user_id, wager, &(&1 + 1))}
        #   else
        #     acc
        #   end
        # end

        # [{_, winners}, {_, losers}] =
        #   for outcome <- outcomes do
        #     {_total_wagered, _participants} = Enum.reduce(outcome, {0, 0}, wage_reducer)
        #   end
        #   |> Enum.sort_by(&elem(&1, 0), :asc)

        #   sender_cs = User.changeset(sender, %{"coins" => sender.coins - amount})
        #   receiver_cs = User.changeset(receiver, %{"coins" => receiver.coins + amount})
        # multi =
        #   winners
        #   Enum.reduce(Multi.new(), fn {user_id, wager}, multi ->

        #   end)
        #   |> Multi.insert_or_update(:withdraw, sender_cs)
        #   |> Multi.insert_or_update(:deposit, receiver_cs)

        # send success message
        InteractionHandler.respond(
          interaction,
          [content: "Successfully closed prediction!"],
          true
        )
    end
  end

  def handle_interaction(%Interaction{data: %{custom_id: custom_id}} = interaction) do
    [outcome_label, prediction_id_str] = String.split(custom_id, ":")
    user_id = interaction.member.user.id
    prediction_id = String.to_integer(prediction_id_str)

    with {:ok, wager} <- WagerSelections.get_selection({prediction_id, user_id}),
         {:ok, prediction} <-
           PredictionHandler.predict(prediction_id, outcome_label, user_id, wager) do
      Logger.debug(
        "#{interaction.member.user.username} predicted \"#{outcome_label}\" with #{wager} Pobcoin"
      )

      embed =
        SlashCommand.Prediction.create_prediction_embed(prediction.prompt, prediction.outcomes)

      Nostrum.Api.edit_interaction_response(Nostrum.Cache.Me.get().id, prediction.token, %{
        embeds: [embed]
      })

      InteractionHandler.respond(interaction, [])
    else
      :submissions_closed ->
        response = [content: "Sorry, submissions have closed for this prediction!"]

        InteractionHandler.respond(interaction, response, true)

      :already_predicted_diff_outcome ->
        response = [content: "You've already predicted a different outcome, haha"]

        InteractionHandler.respond(interaction, response, true)

      :error ->
        response = [content: "You need to select a valid wager before predicting"]

        InteractionHandler.respond(interaction, response, true)

      e ->
        Logger.error(
          "Something went wrong with a button press: Unknown response from PredictionHandler: #{inspect(e)}"
        )

        response = [content: "Uh oh, something went very wrong, please try again in a bit."]

        InteractionHandler.respond(interaction, response, true)
    end
  end
end
