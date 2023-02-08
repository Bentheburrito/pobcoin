defmodule SlashCommand.GivePoint do
  require Logger

  alias Ecto.Multi
  alias Nostrum.Struct.Interaction
  alias Pobcoin.{Repo, User}

  @behaviour SlashCommand

  @impl SlashCommand
  def command_definition() do
    %{
      type: 3,
      name: "Give Friendly February Point",
      description: ""
    }
  end

  @impl SlashCommand
  def command_scope() do
    {:guild, Application.get_env(:pobcoin, :guilds, [])}
  end

  @impl SlashCommand
  def ephemeral?, do: true

  @impl SlashCommand
  def run(%Interaction{} = interaction) do
    message =
      interaction.data.resolved.messages
      |> Enum.take(1)
      |> List.first()
      |> elem(1)

    %User{first_point_ready_at: dt1, second_point_ready_at: dt2} =
      sender_user = Utils.get_or_new(interaction.user.id)

    dt1 = if is_nil(dt1), do: DateTime.utc_now(), else: dt1
    dt2 = if is_nil(dt2), do: DateTime.utc_now(), else: dt2
    now = DateTime.utc_now()

    # Both points are not available yet
    cond do
      message.author.id == interaction.user.id ->
        {:response,
         [
           content:
             "lmfao don't be a poopy, you can't give yoruself a friend point :rofl: :rofl: :rofl: :rofl: :rofl:"
         ]}

      message.author.bot ->
        {:response,
         [
           content: "bots aren't friendly, especially me :middle_finger:"
         ]}

      DateTime.compare(now, dt1) == :lt and DateTime.compare(now, dt2) == :lt ->
        next_ready_at = (DateTime.diff(dt1, dt2, :millisecond) < 0 && dt1) || dt2

        {:response,
         [
           content:
             "I couldn't give #{message.author} your friend point because you've already given two today. Your next friend point will be available at #{Utils.discord_date_format(next_ready_at)}"
         ]}

      :else ->
        point_field_name =
          if DateTime.compare(dt1, now) == :lt do
            "first_point_ready_at"
          else
            "second_point_ready_at"
          end

        sender_cs =
          User.changeset(sender_user, %{
            point_field_name => DateTime.add(now, 24 * 60 * 60, :second)
          })

        author_user = Utils.get_or_new(message.author.id)

        author_cs =
          User.changeset(author_user, %{"friend_points" => author_user.friend_points + 1})
          |> IO.inspect(label: "AUTHOR CS")

        Multi.new()
        |> Multi.insert_or_update(:author, author_cs)
        |> Multi.insert_or_update(:sender, sender_cs)
        |> Repo.transaction()
        |> case do
          {:ok, _map} ->
            next_point_dt = if point_field_name == "first_point_ready_at", do: dt2, else: dt1

            next_point_message =
              if DateTime.compare(next_point_dt, now) == :lt do
                "You can give 1 more point today"
              else
                "Your next point will be available at #{Utils.discord_date_format(next_point_dt)}"
              end

            {:response,
             [
               content:
                 ":white_check_mark: Successfully gave #{message.author} your friend point! #{next_point_message}"
             ]}

          {:error, fail_op, fail_val, _} ->
            Logger.error("""
            Could not grant #{interaction.user.id}'s friendly point to #{message.author.id}.
            failed op: #{inspect(fail_op)}, failed val: #{inspect(fail_val)}
            """)

            {:response,
             [
               content:
                 "uh oh, snow is a dumbass and an error occurred while trying to give a point to #{message.author}"
             ]}
        end
    end
  end
end
