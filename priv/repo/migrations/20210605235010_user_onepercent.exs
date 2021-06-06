defmodule Pobcoin.Repo.Migrations.UserOnepercent do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :one_percenter, :boolean, default: false
    end
  end
end
