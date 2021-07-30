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
    {:guild, Application.get_env(:pobcoin, :guilds, [])}
  end

  @impl SlashCommand
  def ephemeral?, do: true

  @impl SlashCommand
  def run(%Interaction{} = interaction) do
    attrs = %{"user_id" => interaction.member.user.id, "coins" => 100}
    changeset = User.changeset(%User{}, attrs)

    case Pobcoin.Repo.insert(changeset) do
      {:ok, %User{} = _user} ->
        {:response, [content: @success_message]}

      {:error, %Ecto.Changeset{errors: [user_id: {"has already been taken", _constraint_list}]}} ->
        {:response, [content: "You've already been registered with Pobcoin."]}

      {:error, %Ecto.Changeset{} = changeset} ->
        Logger.error("ERROR INSERTING NEW USER INTO DB (/register): #{inspect changeset.errors}")
        {:response, [content: @error_message]}
    end
  end
end
