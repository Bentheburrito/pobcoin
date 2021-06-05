defmodule SlashCommand.Transfer do
  require Logger

  alias Nostrum.Struct.Interaction
  alias Pobcoin.{User, Repo}
  alias Ecto.Multi

  import Ecto.Query

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
    sender = get_or_new(interaction.member.user.id)
    receiver = get_or_new(target_id)

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
        target_user = case Nostrum.Cache.UserCache.get(target_id) do
          {:ok, %Nostrum.Struct.User{} = user} -> user
          {:error, _} -> "them"
        end
        {:message, "Successfully transferred #{amount} Pobcoin to #{target_user}!\nYour remaining balance is #{sender.coins - amount}"}

      {:error, :withdraw, %Ecto.Changeset{errors: [coins: {@overdraft_msg, _list}]}, _changes_so_far} ->
        {:message, "Tbqfh it doesn't seem like you can afford that :/ (Transfer would result in overdraft)"}

      {:error, _, _, _} ->
        {:message, "Uhh something's gone horribly wrong I'm sorry lol\n\n(it didn't work)"}
    end
  end

  defp get_or_new(user_id) do
    case Repo.one(from p in User, where: p.user_id == ^user_id) do
      nil -> %User{user_id: user_id, coins: 100}

      %User{} = user -> user
    end
  end
end
