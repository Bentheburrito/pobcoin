defmodule Buttons do
  alias Nostrum.Struct.Interaction

  def handle_interaction(%Interaction{data: %{custom_id: "pobcoin_selector", values: [pobcoin_amount_str]}} = interaction) do
    IO.inspect interaction
  end
end
