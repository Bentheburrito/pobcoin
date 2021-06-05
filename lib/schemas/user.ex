defmodule Pobcoin.User do
	use Ecto.Schema
	import Ecto.Changeset
  @primary_key {:user_id, :id, autogenerate: false}

  schema "users" do
    field :coins, :integer, default: 100
	end

	def changeset(user, params \\ %{}) do
		user
		|> cast(params, [:user_id, :coins])
		|> validate_required([:user_id, :coins])
    |> validate_number(:coins, greater_than_or_equal_to: 0)
    |> unique_constraint(:user_id)
	end
end
