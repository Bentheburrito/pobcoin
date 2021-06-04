defmodule SlashCommand.Ping do
  alias Nostrum.Struct.Interaction

  @behaviour SlashCommand

  @impl SlashCommand
  def command_definition() do
    %{
      name: "ping",
      description: "Pings the bot.",
    }
  end

  @impl SlashCommand
  def command_scope() do
    {:guild, 381258048527794197}
  end

  @impl SlashCommand
  def run(%Interaction{} = _interaction) do
    {:message, "pong!"}
  end
end
