defmodule SlashCommand do
  use Agent

  require Logger

  alias Nostrum.Api
  alias Nostrum.Struct.{Interaction, Embed}

  @moduledoc """
  A behaviour for defining Slash Commands.
  """

  @callback command_definition() :: map()
  @callback command_scope() ::
              :global
              | {:guild, guild_id :: Nostrum.Snowflake.t()}
              | {:guilds, [guild_id :: Nostrum.Snowflake.t()]}
  @callback run(Interaction.t()) :: {:response, map()} | {:message, String.t()} | {:embed, Embed.t()}

  def start_link(_init_args) do
		Agent.start_link(fn -> %{} end, name: __MODULE__)
	end

  ### Public
	def get(command_name) do
		Agent.get(__MODULE__, &Map.get(&1, command_name, :notacommand))
	end

  def put(command_module) do
    %{name: command_name} = apply(command_module, :command_definition, [])
    Agent.update(__MODULE__, &Map.put(&1, command_name, {command_module, nil}))
    register_command(command_module)
  end

  def put_register(command_name, reg_ack) do
    Agent.update(__MODULE__, &Map.update!(&1, command_name, fn {command_module, _} -> {command_module, reg_ack} end))
  end

  def delete(command_name) do
    {module, reg_ack} = Agent.get_and_update(__MODULE__, &Map.pop(&1, command_name))
    unregister_command(module, reg_ack)
  end

	def list do
		Agent.get(__MODULE__, &(&1))
	end

  def get_options(%Interaction{data: data}) do
    names = get_in(data, [:options, Access.all(), :name])
    values = get_in(data, [:options, Access.all(), :value])
    |> Enum.map(fn val when is_binary(val) ->
      case Integer.parse(val) do
        {num, _} -> num
        :error -> val
      end
      val -> val
    end)
    Enum.zip(names, values) |> Map.new()
  end

  def handle_interaction(%Interaction{data: %{name: name}} = interaction) do
    case get(name) do
      :notacommand -> Logger.error("INTERACTION RECEIVED FOR UNKNOWN COMMAND: #{name}")
      {module, _reg_ack} ->
        case apply(module, :run, [interaction]) do
          {:response, res} when is_map(res) ->
            Api.create_interaction_response(interaction, res)
          {:message, message} when is_binary(message) ->
            Api.create_interaction_response(interaction, message_interaction_response(message))
          {:embed, %Embed{} = embed} ->
            Api.create_interaction_response(interaction, embed_interaction_response(embed))
        end
    end
  end

  ### Impl
  def init_commands() do
    with {:ok, list} <- :application.get_key(:pobcoin, :modules) do
      list
      |> Enum.filter(&match?(["SlashCommand", _command], Module.split(&1)))
      |> Enum.each(&put/1)
    end
  end

  defp register_command(command_module) do

    definition = apply(command_module, :command_definition, [])
    scope = apply(command_module, :command_scope, [])

    case scope do
      :global -> Api.create_global_application_command(definition)
      {:guild, guild_id} -> Api.create_guild_application_command(guild_id, definition)
      {:guilds, guild_ids} -> Enum.each(guild_ids, &Api.create_guild_application_command(&1, definition))
    end
  end

  defp unregister_command(command_module, command_reg_ack) do
    scope = apply(command_module, :command_scope, [])

    case scope do
      :global -> Api.delete_global_application_command(command_reg_ack.id)
      {:guild, guild_id} -> Api.delete_guild_application_command(guild_id, command_reg_ack.id)
      {:guilds, guild_ids} -> Enum.each(guild_ids, &Api.delete_guild_application_command(&1, command_reg_ack.id))
    end
  end

  defp message_interaction_response(message) do
    %{
      type: 4, # ChannelMessageWithSource
      data: %{
        content: message
      }
    }
  end

  defp embed_interaction_response(_embed) do
    %{

    }
  end
end
