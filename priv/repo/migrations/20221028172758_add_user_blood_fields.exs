defmodule Pobcoin.Repo.Migrations.AddUserBloodFields do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :blood, :integer, default: 20
      add :last_donation, :utc_datetime, default: nil
      add :last_sucked, :utc_datetime, default: nil
      add :last_take, :utc_datetime, default: nil
    end
  end
end
