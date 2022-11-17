defmodule Pobcoin.GuessWhoEntry do
  use Ecto.Schema
  import Ecto.Changeset
  @primary_key {:id, :id, autogenerate: false}

  schema "guess_who_entries" do
    field(:submitter_id, :integer)
    field(:message_text, :string)
    field(:message_id, :integer)
    field(:channel_id, :integer)
    field(:correct_answer_id, :integer)
    field(:last_used_at, :utc_datetime, default: nil)
  end

  @fields [
    :submitter_id,
    :message_text,
    :message_id,
    :channel_id,
    :correct_answer_id,
    :last_used_at
  ]

  def changeset(guess_who_entry, params \\ %{}) do
    guess_who_entry
    |> cast(params, @fields)
    |> validate_required(List.delete(@fields, :last_used_at))
  end
end
