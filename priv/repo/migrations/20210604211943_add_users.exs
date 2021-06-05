defmodule Pobcoin.Repo.Migrations.AddUsers do
  use Ecto.Migration

  def change do

    create table(:users) do
			add :user_id, :bigint, primary_key: true
			add :coins, :integer
		end
    create unique_index(:users, [:user_id])
  end
end
