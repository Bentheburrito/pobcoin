defmodule SlashCommand.Transfer do
  require Logger

  alias Nostrum.Struct.{Interaction, Embed}
  alias Nostrum.Struct.User, as: DiscordUser
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
        },
        %{
          # ApplicationCommandType::STRING
          type: 3,
          name: "memo",
          description: "An optional memo for the transaction (200 character max).",
          required: false,
        }
      ]
    }
  end

  @impl SlashCommand
  def command_scope() do
    {:guild, Application.get_env(:pobcoin, :guilds, [])}
  end

  @impl SlashCommand
  def run(%Interaction{} = interaction) do
    %{"user" => target_id, "amount" => amount} = args = SlashCommand.get_options(interaction)
    memo = Map.get(args, "memo")

    %DiscordUser{} = target_user = Nostrum.Api.get_user!(target_id)

    # Additional parameter checks
    cond do
      target_id == interaction.member.user.id ->
        {:message, "Come on man, that doesn't even make sense. (You can't transfer Pobcoin to yourself)"}
      amount == 0 ->
        {:message, "Pleeeeease stop wasting my time. (You can't transfer zero Pobcoin)"}
      amount < 0 ->
        {:message, "Nice try, hon. (You can't transfer negative Pobcoin)"}
      target_user.bot ->
        {:message, "You can't transfer Pobcoin to bots, silly goose."}
      not is_nil(memo) and memo |> to_string() |> String.length() > 200 ->
        {:message, "That memo is wayyy too wordy. (It can be up to 200 characters)"}
      true ->
        transfer(interaction, target_user, amount, memo)
    end
  end

  defp transfer(%Interaction{} = interaction, %DiscordUser{} = target_user, amount, memo) do
    # Get both users' data from DB. If they haven't registered yet, make a new struct for them.
    sender = Utils.get_or_new(interaction.member.user.id)
    receiver = Utils.get_or_new(target_user.id)

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
        Pobcoin.determine_one_percenters()

        description = "Successfully transferred #{amount} Pobcoin to #{target_user}!"
          <> if not is_nil(memo), do: "\n**Memo**: *#{memo}*", else: ""

        embed =
          %Embed{}
          |> Embed.put_author(interaction.member.user.username, nil, Nostrum.Struct.User.avatar_url(interaction.member.user))
          |> Embed.put_footer(target_user.username, Nostrum.Struct.User.avatar_url(target_user))
          |> Embed.put_description(description)
          |> Embed.put_field(interaction.member.user.username, "#{sender.coins} - #{amount} = **#{sender.coins - amount}**", true)
          |> Embed.put_field("<:pobcoin:850900816826073099>", "**#{amount} →**", true)
          |> Embed.put_field(target_user.username, "#{receiver.coins} + #{amount} = **#{receiver.coins + amount}**", true)
          |> Embed.put_color(Pobcoin.good_green())
          |> Embed.put_thumbnail(Pobcoin.pob_dollar_image_url())

        {:embed, embed}

      {:error, :withdraw, %Ecto.Changeset{errors: [coins: {@overdraft_msg, _list}]}, _changes_so_far} ->
        {:message, "Tbqfh it doesn't seem like you can afford that :/ (Transfer of #{amount} would result in overdraft)"}

      {:error, fail_op, fail_val, _} ->
        Logger.error("ERROR INSERTING OR UPDATING USER (/transfer #{target_user} #{amount}): #{inspect fail_op, label: "fail op"} #{inspect fail_val, label: "fail val"}")
        {:message, "Uhh something's gone horribly wrong I'm sorry lol\n\n(it didn't work)"}
    end
  end
end
