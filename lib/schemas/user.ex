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
    |> unique_constraint(:user_id)
	end
end
