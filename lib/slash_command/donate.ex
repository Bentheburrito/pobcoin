defmodule SlashCommand.Donate do
  require Logger

  alias Nostrum.Struct.Interaction
  alias Pobcoin.{User, Repo}
  alias Ecto.Multi

  @behaviour SlashCommand

  @overdraft_msg "must be greater than or equal to %{number}"

  @blood_amount 1

  @impl SlashCommand
  def command_definition() do
    %{
      name: "donateblood",
      description: "Donate blood to the blood drive"
    }
  end

  @impl SlashCommand
  def command_scope() do
    {:guild, Application.get_env(:pobcoin, :guilds, [])}
  end

  @impl SlashCommand
  def run(%Interaction{} = interaction) do
    target_id = 0

    # Get both users' data from DB. If they haven't registered yet, make a new struct for them.
    sender = Utils.get_or_new(interaction.member.user.id)
    receiver = Utils.get_or_new(target_id)

    cond do
      sender.blood == 0 ->
        {:response, [content: "you are dead. so weird lmfao"]}

      true ->
        # Create changesets with proposed balance changes.
        sender_cs = User.changeset(sender, %{"blood" => sender.blood - @blood_amount})
        receiver_cs = User.changeset(receiver, %{"blood" => receiver.blood + @blood_amount})
        new_pobcoin_cs = User.changeset(sender, %{"coins" => sender.coins + 5})

        # Prepare multi for transaction.
        multi =
          Multi.new()
          |> Multi.insert_or_update(:withdraw, sender_cs)
          |> Multi.insert_or_update(:deposit, receiver_cs)
          |> Multi.insert_or_update(:interest, new_pobcoin_cs)

        # Do the transaction.
        case Repo.transaction(multi) do
          {:ok, _map} ->
            description =
              "Successfully donated #{@blood_amount} to the Blood Drive! The Blood Drive now has #{receiver.blood + @blood_amount} blood, and you earned 5 Pobcoin!."

            {:response, [content: description]}

          {:error, :withdraw, %Ecto.Changeset{errors: [coins: {@overdraft_msg, _list}]},
           _changes_so_far} ->
            {:response,
             [
               content: "you can't do that you would die!!!!1 so weird lmfao"
             ]}

          {:error, fail_op, fail_val, _} ->
            Logger.error(
              "ERROR INSERTING OR UPDATING USER (/donate): #{inspect(fail_op, label: "fail op")} #{inspect(fail_val, label: "fail val")}"
            )

            {:response,
             [content: "Uhh something's gone horribly wrong I'm sorry lol\n\n(it didn't work)"]}
        end
    end
  end
end
