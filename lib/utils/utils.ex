defmodule Utils do
  alias Pobcoin.{User, Repo}

  import Ecto.Query

  @doc """
  Get a user's Pobcoin struct from the DB, or create a new struct for them if it doesn't exist.
  """
  @spec get_or_new(user_id :: Nostrum.Snowflake.t()) :: %User{}
  def get_or_new(user_id) do
    case Repo.one(from(p in User, where: p.user_id == ^user_id)) do
      nil ->
        %User{user_id: user_id, coins: 100}
        |> Repo.insert()

      %User{} = user ->
        user
    end
  end

  @spec update_in(Access.t(), [term, ...], term, (term -> term)) :: Access.t()
  def update_in(data, keys, default, fun) do
    case get_in(data, keys) do
      nil -> put_in(data, keys, default)
      value -> put_in(data, keys, fun.(value))
    end
  end

  def hash_outcome_label(label) do
    :crypto.hash(:md5, label)
    |> Base.encode16()
  end
end
