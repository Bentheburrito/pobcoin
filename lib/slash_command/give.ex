defmodule SlashCommand.Give do
  require Logger

  alias Nostrum.Struct.Interaction
  alias Pobcoin.{Repo, User}

  @behaviour SlashCommand

  @impl SlashCommand
  def command_definition() do
    %{
      name: "give",
      description: "Create Pobcoin and give it to a user.",
      options: [
        %{
          # ApplicationCommandType::USER
          type: 6,
          name: "user",
          description: "User to give the new Pobcoin to.",
          required: true
        },
        %{
          # ApplicationCommandType::INTEGER
          type: 4,
          name: "amount",
          description: "The amount of Pobcoin to create.",
          required: true,
        }
      ],
      # Aight apparently Discord makes you do a separate PUT request with specific permissions,
      # and Nostrum doesn't have an easy way to do that so I'm handing perms locally woooooo
      # default_permission: false,
      # permissions: [
      #   %{
      #       id: 214126944395067392,
      #       type: 2,
      #       permission: true
      #   },
      #   %{
      #     id: 254728052070678529,
      #     type: 2,
      #     permission: true
      #   }
      # ]
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
      interaction.member.user.id not in Application.get_env(:pobcoin, :pobcoin_oligarchs, []) ->
        {:message, "I'm the captain of this ship and I will [ban you for trying to inflate Pobcoin]! (/give is for Cousin Pob only)"}
      amount == 0 ->
        {:message, "*message deleted by a moderator.*\n\n(You can't create zero Pobcoin)"}
      amount < 0 ->
        {:message, "lmfapooooo nice try. (You can't create negative Pobcoin)"}
      true ->
        give(interaction, target_id, amount)
    end
  end

  defp give(%Interaction{} = _interaction, target_id, amount) do
    user = Utils.get_or_new(target_id)

    changeset = User.changeset(user, %{"coins" => user.coins + amount})

    case Repo.insert_or_update(changeset) do
      {:ok, _map} ->
        target_user = case Nostrum.Api.get_user(target_id) do
          {:ok, %Nostrum.Struct.User{} = user} -> user
          _error -> "them"
        end
        {:message, "Successfully created and gave #{amount} Pobcoin to #{target_user}!"}

      {:error, %Ecto.Changeset{errors: errors}} ->
        Logger.error("ERROR INSERTING OR UPDATING USER (/give #{target_id} #{amount}): #{inspect errors}")
        {:message, "Uhh something's gone horribly wrong I'm sorry lol\n\n(it didn't work)"}
    end
  end
end
