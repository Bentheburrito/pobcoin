defmodule Pobcoin.InteractionHandler do
  alias Nostrum.Struct.Interaction

  def handle_interaction(%Interaction{data: %{name: _name}} = interaction) do
    SlashCommand.handle_interaction(interaction)
  end

  def handle_interaction(%Interaction{data: %{custom_id: _custom_id}} = interaction) do
    Buttons.handle_interaction(interaction)
  end
end
