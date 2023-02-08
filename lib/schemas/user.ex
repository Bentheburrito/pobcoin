defmodule Pobcoin.User do
  use Ecto.Schema
  import Ecto.Changeset
  @primary_key {:user_id, :id, autogenerate: false}

  schema "users" do
    field(:coins, :integer, default: 100)
    field(:one_percenter, :boolean, default: false)
    field(:friend_points, :integer, default: 0)
    field(:first_point_ready_at, :utc_datetime)
    field(:second_point_ready_at, :utc_datetime)
  end

  @all_fields [
    :user_id,
    :coins,
    :one_percenter,
    :friend_points,
    :first_point_ready_at,
    :second_point_ready_at
  ]

  @required_fields [
    :user_id,
    :coins
  ]

  def changeset(user, params \\ %{}) do
    user
    |> cast(params, @all_fields)
    |> validate_required(@required_fields)
    |> validate_number(:coins, greater_than_or_equal_to: 0)
    |> validate_number(:friend_points, greater_than_or_equal_to: 0)
    |> unique_constraint(:user_id)
  end
end
