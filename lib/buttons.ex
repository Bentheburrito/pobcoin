defmodule Buttons do
  alias Ecto.Multi
  alias Nostrum.Struct.Interaction
  alias Pobcoin.InteractionHandler
  alias Pobcoin.PredictionHandler.WagerSelections
  alias Pobcoin.PredictionHandler
  alias Pobcoin.{Repo, User}

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
        %Interaction{
          data: %{
            custom_id:
              "close:" <> <<outcome_label_hash::binary-size(32)>> <> ":" <> prediction_id_str
          }
        } = interaction
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

        {channel_id, message_id} = prediction.token

        Nostrum.Api.edit_message(channel_id, message_id, %{
          embeds: [embed],
          components: components
        })

        # distribute pobcoin
        {:ok, {winning_outcome, losing_outcome}} =
          Map.fetch(prediction.label_map, outcome_label_hash)

        {winners_votes, winners_wagered} =
          Map.get(prediction.outcomes, winning_outcome)
          |> then(fn votes ->
            total_wagered =
              votes
              |> Map.values()
              |> Enum.sum()

            {votes, total_wagered}
          end)

        {losers_votes, losers_wagered} =
          Map.get(prediction.outcomes, losing_outcome)
          |> then(fn votes ->
            total_wagered =
              votes
              |> Map.values()
              |> Enum.sum()

            {votes, total_wagered}
          end)

        total_wagered = winners_wagered + losers_wagered
        profit_ratio = total_wagered / winners_wagered

        multi_winners =
          winners_votes
          |> Enum.reduce(Multi.new(), fn {user_id, wager}, multi ->
            case Repo.get(User, user_id) do
              nil ->
                Logger.error("#{user_id} predicted in #{id} but they have no entry in DB.")
                multi

              %User{} = user ->
                attrs = %{"coins" => user.coins - wager + floor(wager * profit_ratio)}
                cs = User.changeset(user, attrs)
                Multi.insert_or_update(multi, "winner:#{user_id}", cs)
            end
          end)

        multi =
          losers_votes
          |> Enum.reduce(multi_winners, fn {user_id, wager}, multi ->
            case Repo.get(User, user_id) do
              nil ->
                Logger.error("#{user_id} predicted in #{id} but they have no entry in DB.")
                multi

              %User{} = user ->
                cs = User.changeset(user, %{"coins" => user.coins - wager})
                Multi.insert_or_update(multi, "loser:#{user_id}", cs)
            end
          end)

        case Repo.transaction(multi) do
          {:ok, _map} ->
            response = [
              content: """
              **#{prediction.prompt}**
              :tada: ~#{winning_outcome}~ :tada:
              #{total_wagered} pobcoin goes to #{map_size(winners_votes)} predictors!
              1:#{profit_ratio} |
              check your current balance of pobcoin with /pobcoin
              """
            ]

            InteractionHandler.respond(interaction, response)

          {:error, failed_operation, failed_value, _changes_so_far} ->
            Logger.error("""
            FAILED TO DISTRIBUTE POBCOIN AFTER PREDICTION CLOSE
            failed operation: #{inspect(failed_operation)}
            failed value: #{inspect(failed_value)}
            prediction (#{id}): #{inspect(prediction)}
            """)

            response = [
              content:
                "uhh I wasn't able to distribute the pobcoin for a prediction, sorry!..Blame @Snowful#1234"
            ]

            InteractionHandler.respond(interaction, response)
        end
    end
  end

  def handle_interaction(%Interaction{data: %{custom_id: custom_id}} = interaction) do
    [outcome_label_hash, prediction_id_str] = String.split(custom_id, ":")
    user_id = interaction.member.user.id
    prediction_id = String.to_integer(prediction_id_str)

    with {:ok, wager} <- WagerSelections.get_selection({prediction_id, user_id}),
         {:ok, prediction} <-
           PredictionHandler.predict(
             prediction_id,
             {:hashed_label, outcome_label_hash},
             user_id,
             wager
           ) do
      Logger.debug(
        "#{interaction.member.user.username} predicted \"#{outcome_label_hash}\" with #{wager} Pobcoin"
      )

      embed =
        SlashCommand.Prediction.create_prediction_embed(prediction.prompt, prediction.outcomes)

      {channel_id, message_id} = prediction.token

      Nostrum.Api.edit_message(channel_id, message_id, %{
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
