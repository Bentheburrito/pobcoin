defmodule SlashCommand.Give do
  require Logger

  alias Nostrum.Struct.Interaction
  alias Pobcoin.{Repo, User}

  @behaviour SlashCommand

  @impl SlashCommand
  def command_definition() do
    %{
      name: "give",
      description: "Create Pobcoin and give it to a user (for use by Pobert only).",
      options: [
        %{
          # ApplicationCommandType::USER
          type: 6,
          name: "user",
          description: "User to give the new Pobcoin to. (seriously if you're not Pob stop using this command maybe ok thx!)",
          required: true
        },
        %{
          # ApplicationCommandType::INTEGER
          type: 4,
          name: "amount",
          description: "The amount of Pobcoin to create. (I swear to James's God if you're not Pob I'm gonna-)",
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
    {:guild, Application.get_env(:pobcoin, :guilds, [])}
  end

  @impl SlashCommand
  def run(%Interaction{} = interaction) do
    %{"user" => target_id, "amount" => amount} = SlashCommand.get_options(interaction)
    cond do
      interaction.member.user.id not in Application.get_env(:pobcoin, :oligarchs, []) ->
        {:response, [content: "You're not pob, impobster (`/give` is for Pobsterlot only - did you mean to use `/transfer`?)"]}
      amount == 0 ->
        {:response, [content: "*message deleted by a moderator.*\n\n(You can't create zero Pobcoin)"]}
      amount < 0 ->
        {:response, [content: "lmfaopooooo nice try. (You can't create negative Pobcoin)"]}
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
        Pobcoin.determine_one_percenters()
        {:response, [content: "Successfully created and gave #{amount} Pobcoin to #{target_user}!"]}

      {:error, %Ecto.Changeset{errors: errors}} ->
        Logger.error("ERROR INSERTING OR UPDATING USER (/give #{target_id} #{amount}): #{inspect errors}")
        {:response, [content: "Uhh something's gone horribly wrong I'm sorry lol\n\n(it didn't work)"]}
    end
  end
end
