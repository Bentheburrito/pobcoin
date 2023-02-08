defmodule Pobcoin.Repo.Migrations.AddFriendPointsToUser do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :friend_points, :integer, default: 0
      add :first_point_ready_at, :utc_datetime
      add :second_point_ready_at, :utc_datetime
    end
  end
end
