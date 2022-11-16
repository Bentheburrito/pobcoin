defmodule SlashCommand.Take do
  require Logger

  alias Nostrum.Struct.{Interaction, Embed}
  alias Nostrum.Struct.User, as: DiscordUser
  alias Pobcoin.{User, Repo}
  alias Ecto.Multi

  @behaviour SlashCommand

  @overdraft_msg "must be greater than or equal to %{number}"

  @blood_amount 1

  @impl SlashCommand
  def command_definition() do
    %{
      name: "takeblood",
      description: "Take blood from the blood drive, or another user",
      options: [
        %{
          # ApplicationCommandType::USER
          type: 6,
          name: "user",
          description: "(Optional) user whose blood you're sucking (ew)",
          required: false
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
    args = SlashCommand.get_options(interaction)
    target_id = Map.get(args, "user", 0)

    %DiscordUser{} =
      target_user =
      case Nostrum.Api.get_user(target_id) do
        {:ok, user} ->
          user

        {:error, _} ->
          %DiscordUser{
            id: 0,
            username: "Blood Drive",
            bot: false,
            avatar: nil,
            discriminator: "0001"
          }
      end

    # Additional parameter checks
    cond do
      target_id == interaction.member.user.id ->
        {:response,
         [
           content: "Come on man, that doesn't even make sense. (You can't suck your own blood!)"
         ]}

      target_user.bot ->
        {:response, [content: "Bots don't have blood, silly goose."]}

      true ->
        take(interaction, target_user)
    end
  end

  defp take(%Interaction{} = interaction, %DiscordUser{} = target_user) do
    # Get both users' data from DB. If they haven't registered yet, make a new struct for them.
    taker = Utils.get_or_new(interaction.member.user.id)
    loser = Utils.get_or_new(target_user.id)

    # stopping here, need to check the different last_* fields on user struct before doing taking/donation (donation might
    # be good). migration should be run already
    cond do
      DateTime.compare(taker.last_take)
    end

    # Create changesets with proposed balance changes.
    taker_cs = User.changeset(taker, %{"blood" => taker.blood + @blood_amount})
    loser_cs = User.changeset(loser, %{"blood" => loser.blood - @blood_amount})

    # Prepare multi for transaction.
    multi =
      Multi.new()
      |> Multi.insert_or_update(:withdraw, taker_cs)
      |> Multi.insert_or_update(:deposit, loser_cs)

    # Do the transaction.
    case Repo.transaction(multi) do
      {:ok, _map} ->
        description =
          Enum.random([
            "oh my gosh this is so gross!",
            "yuck man put those things away"
          ])

        embed =
          %Embed{}
          |> Embed.put_author(
            interaction.member.user.username,
            nil,
            Nostrum.Struct.User.avatar_url(interaction.member.user)
          )
          |> Embed.put_footer(target_user.username, Nostrum.Struct.User.avatar_url(target_user))
          |> Embed.put_description(description)
          |> Embed.put_field(
            interaction.member.user.username,
            "#{taker.blood} + #{@blood_amount} = **#{taker.blood + @blood_amount}**",
            true
          )
          |> Embed.put_field(":vampire: :yum:", "**#{@blood_amount} →**", true)
          |> Embed.put_field(
            target_user.username,
            "#{loser.blood} - #{@blood_amount} = **#{loser.blood - @blood_amount}**",
            true
          )
          |> Embed.put_color(Pobcoin.error_red())

        {:response, [embeds: [embed]]}

      {:error, :withdraw, %Ecto.Changeset{errors: [blood: {@overdraft_msg, _list}]},
       _changes_so_far} ->
        msg =
          if target_user.id == 0,
            do: "The blood drive is empty :(",
            else: "you can't do that they are dead lmfao"

        {:response,
         [
           content: msg
         ]}

      {:error, fail_op, fail_val, _} ->
        Logger.error(
          "ERROR INSERTING OR UPDATING USER (/take #{target_user}): #{inspect(fail_op, label: "fail op")} #{inspect(fail_val, label: "fail val")}"
        )

        {:response,
         [content: "Uhh something's gone horribly wrong I'm sorry lol\n\n(it didn't work)"]}
    end
  end
end
