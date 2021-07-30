defmodule Pobcoin.InteractionHandler do
  alias Nostrum.Struct.Interaction

  @type response_data_field ::
    :content |
    :embeds |
    :components

  def handle_interaction(%Interaction{data: %{name: _name}} = interaction) do
    SlashCommand.handle_interaction(interaction)
  end

  def handle_interaction(%Interaction{data: %{custom_id: _custom_id}} = interaction) do
    Buttons.handle_interaction(interaction)
  end

  @spec respond(Interaction.t(), [{response_data_field, any()}], boolean()) :: {:ok} | {:error, any()}
  def respond(%Interaction{} = interaction, data, ephemeral \\ false) do
    data =
      data
      |> Keyword.take([:content, :embeds, :components])
      |> Map.new()

    response =
      %{
        # ChannelMessageWithSource
        type: 4,
        data: data
      }
      |> then(&if ephemeral, do: put_in(&1, [:data, :flags], 64), else: &1)

    Nostrum.Api.create_interaction_response(interaction, response)
  end
end
