defmodule SlashCommand.Transfer do
  require Logger

  alias Nostrum.Struct.Interaction
  alias Pobcoin.{User, Repo}
  alias Ecto.Multi

  @behaviour SlashCommand

  @overdraft_msg "must be greater than or equal to %{number}"

  @impl SlashCommand
  def command_definition() do
    %{
      name: "transfer",
      description: "Transfer Pobcoin to another User.",
      options: [
        %{
          # ApplicationCommandType::USER
          type: 6,
          name: "user",
          description: "User receiving your Pobcoin",
          required: true
        },
        %{
          # ApplicationCommandType::INTEGER
          type: 4,
          name: "amount",
          description: "The amount of Pobcoin to transfer.",
          required: true,
        }
      ]
    }
  end

  @impl SlashCommand
  def command_scope() do
    {:guild, 381258048527794197}
  end

  @impl SlashCommand
  def run(%Interaction{} = interaction) do
    %{"user" => target_id, "amount" => amount} = SlashCommand.get_options(interaction)
    cond do
      target_id == interaction.member.user.id ->
        {:message, "Come on man, that doesn't even make sense. (You can't transfer Pobcoin to yourself)"}
      amount == 0 ->
        {:message, "Pleeeeease stop wasting my time. (You can't transfer zero Pobcoin)"}
      amount < 0 ->
        {:message, "Nice try, hon. (You can't transfer negative Pobcoin)"}
      true ->
        transfer(interaction, target_id, amount)
    end
  end

  defp transfer(%Interaction{} = interaction, target_id, amount) do
    # Get both users' data from DB. If they haven't registered yet, make a new struct for them.
    sender = Utils.get_or_new(interaction.member.user.id)
    receiver = Utils.get_or_new(target_id)

    # Create changesets with proposed balance changes.
    sender_cs = User.changeset(sender, %{"coins" => sender.coins - amount})
    receiver_cs = User.changeset(receiver, %{"coins" => receiver.coins + amount})

    # Prepare multi for transaction.
    multi =
      Multi.new()
      |> Multi.insert_or_update(:withdraw, sender_cs)
      |> Multi.insert_or_update(:deposit, receiver_cs)

    # Do the transaction.
    case Repo.transaction(multi) do
      {:ok, _map} ->
        target_user = case Nostrum.Api.get_user(target_id) do
          {:ok, %Nostrum.Struct.User{} = user} -> user
          _error -> "them"
        end
        {:message, "Successfully transferred #{amount} Pobcoin to #{target_user}!\nYour remaining balance is #{sender.coins - amount}"}

      {:error, :withdraw, %Ecto.Changeset{errors: [coins: {@overdraft_msg, _list}]}, _changes_so_far} ->
        {:message, "Tbqfh it doesn't seem like you can afford that :/ (Transfer of #{amount} would result in overdraft)"}

      {:error, fail_op, fail_val, _} ->
        Logger.error("ERROR INSERTING OR UPDATING USER (/transfer #{target_id} #{amount}): #{inspect fail_op, label: "fail op"} #{inspect fail_val, label: "fail val"}")
        {:message, "Uhh something's gone horribly wrong I'm sorry lol\n\n(it didn't work)"}
    end
  end
end
