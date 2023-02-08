defmodule Pobcoin.FriendlyFebruary do
  alias Nostrum.Api
  alias Pobcoin.{User, Repo}
  alias Ecto.Multi

  require Logger

  @type author_id :: Nostrum.Snowflake.t()
  @type reactor_id :: Nostrum.Snowflake.t()

  @spec handle_reaction(author_id, reactor_id) :: :ok | {:no_points_ready, DateTime.t()} | :error
  def handle_reaction(author_id, reactor_id) do
    %User{first_point_ready_at: dt1, second_point_ready_at: dt2} =
      reactor_user = Utils.get_or_new(reactor_id)

    now = DateTime.utc_now()

    # Both points are not available yet
    if DateTime.compare(now, dt1) == :lt and DateTime.compare(now, dt2) == :lt do
      next_ready_at = (DateTime.diff(dt1, dt2, :millisecond) < 0 && dt1) || dt2
      {:no_points_ready, next_ready_at}
    else
      point_field_name =
        if DateTime.compare(dt1, now) == :lt do
          "first_point_ready_at"
        else
          "second_point_ready_at"
        end

      reactor_cs =
        User.changeset(reactor_user, %{point_field_name => DateTime.add(now, 24, :hour)})

      author_user = Utils.get_or_new(author_id)
      author_cs = User.changeset(author_user, %{"friend_points" => author_user.friend_points + 1})

      Multi.new()
      |> Multi.insert_or_update(:author, author_cs)
      |> Multi.insert_or_update(:reactor, reactor_cs)
      |> Repo.transaction()
      |> case do
        {:ok, _map} ->
          :ok

        {:error, fail_op, fail_val, _} ->
          Logger.error("""
          Could not grant #{reactor_id}'s friendly point to #{author_id}.
          failed op: #{inspect(fail_op)}, failed val: #{inspect(fail_val)}
          """)

          :error
      end
    end
  end

  def alert_failed_transaction!(reaction, message) do
    dm_channel = Api.create_dm!(reaction.user_id)
    Api.create_message!(dm_channel.id, message)

    Api.delete_user_reaction!(
      reaction.channel_id,
      reaction.message_id,
      reaction.emoji,
      reaction.user_id
    )
  end
end
