defmodule Utils do
  alias Pobcoin.{User, Repo}

  import Ecto.Query

  @doc """
  Get a user's Pobcoin struct from the DB, or create a new struct for them if it doesn't exist.
  """
  @spec get_or_new(user_id :: Nostrum.Snowflake.t()) :: %User{}
  def get_or_new(user_id) do
    case Repo.one(from(p in User, where: p.user_id == ^user_id)) do
      nil -> %User{user_id: user_id, coins: 100}
      %User{} = user -> user
    end
  end
end
