defmodule Pobcoin.Repo.Migrations.AddGuessWhoEntries do
  use Ecto.Migration

  def change do
    create table(:guess_who_entries) do
      add :submitter_id, :bigint
      add :message_text, :string
      add :message_id, :bigint
      add :channel_id, :bigint
      add :correct_answer_id, :bigint
      add :last_used_at, :utc_datetime, default: nil
    end
  end
end
