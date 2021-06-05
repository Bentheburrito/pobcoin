defmodule SlashCommand.Register do
  require Logger

  alias Nostrum.Struct.Interaction
  alias Pobcoin.User

  @behaviour SlashCommand

  @success_message "Successfully registered! You now have 100 Pobcoin!"
  @error_message "Oops, there was a problem registering you for Pobcoin. Please try again in a bit, the developer has been notified"

  @impl SlashCommand
  def command_definition() do
    %{
      name: "register",
      description: "Registers a user with Pobcoin.",
    }
  end

  @impl SlashCommand
  def command_scope() do
    {:guild, 381258048527794197}
  end

  @impl SlashCommand
  def run(%Interaction{} = interaction) do
    attrs = %{"user_id" => interaction.member.user.id, "coins" => 100}
    changeset = User.changeset(%User{}, attrs)

    case Pobcoin.Repo.insert(changeset) do
      {:ok, %User{} = _user} ->
        {:message, @success_message}

      {:error, %Ecto.Changeset{errors: [user_id: {"has already been taken", _constraint_list}]}} ->
        {:message, "You've already been registered with Pobcoin."}

      {:error, %Ecto.Changeset{} = changeset} ->
        Logger.error("ERROR INSERTING USER INTO DB (/register): #{inspect changeset.errors}")
        {:message, @error_message}
    end
  end
end
