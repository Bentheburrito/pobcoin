defmodule SlashCommand.BabyTalk do
  require Logger

  alias Nostrum.Struct.Interaction

  @behaviour SlashCommand

  @impl SlashCommand
  def command_definition() do
    %{
      type: 3,
      name: "Translate to Baby Talk",
      description: ""
      # "Are you a baby? Do you have trouble reading adults' messages? Then this is the command for you!"
    }
  end

  @impl SlashCommand
  def command_scope() do
    {:guild, Application.get_env(:pobcoin, :guilds, [])}
  end

  @impl SlashCommand
  def run(%Interaction{} = interaction) do
    message =
      interaction.data.resolved.messages
      |> Enum.take(1)
      |> List.first()
      |> elem(1)

    translated_content =
      message.content
      |> String.replace(["r", "l"], "w")
      |> String.replace(["R", "L"], "W")
      |> String.replace(~r/the([\s,.\?\!])/, "da\\g{1}")
      |> String.replace(~r/the([\s,.\?\!])/i, "Da\\g{1}")
      |> String.replace(~r/th([\s,.\?\!])/, "f\\g{1}")
      |> String.replace(~r/th([\s,.\?\!])/i, "F\\g{1}")
      |> String.replace("th", "d")
      |> String.replace(~r/th/i, "D")
      |> String.replace("tt", "dd")
      |> then(
        &if String.length(&1) > 2000 do
          String.slice(&1, 0..1994) <> "[...]"
        else
          &1
        end
      )

    {:response,
     [
       content: translated_content,
       allowed_mentions: %{
         parse: []
       }
     ]}
  end
end
