defmodule Pobcoin.Twitch do
  require Logger

  alias TwitchEx.EventSub.Transports.WebHook
  alias TwitchEx.EventSub.Subscription
  alias TwitchEx.EventSub

  @pobsterlot_user_id "195993788"
  @snowfully_user_id "74779625"
  @bombad_general_channel_id 747_619_333_869_666_344

  @new_stream_messages [
    "oh my freaking gosh, Pobsterlot is live at https://twitch.tv/pobsterlot",
    "Pobsterlot is live at https://twitch.tv/pobsterlot ! This is the best day of my fucking life!",
    "Pob is live at https://twitch.tv/pobsterlot <:POB_CHAMP2:771235682013937664> <:POB_CHAMP2:771235682013937664>",
    "WOOOHOOOOO HE'S LIVE https://twitch.tv/pobsterlot",
    "<:FallGuy2:870273932232650772><:quoteLeft:791419272035041310>go to https://twitch.tv/pobsterlot NOW!!!!11<:quoteRight:791419272106213387>"
  ]

  @doc """
  list of subscription {type, condition, version} triplets
  """
  def eventsub_subscriptions do
    [
      {"stream.online", %{"broadcaster_user_id" => @pobsterlot_user_id}, "1"},
      {"channel.update", %{"broadcaster_user_id" => @pobsterlot_user_id}, "1"},
      {"channel.update", %{"broadcaster_user_id" => @snowfully_user_id}, "1"}
    ]
  end

  @doc """
  Gets a list of currently subscribed to events, then subscribes to those that don't match `eventsub_subscriptions/0`.
  Should probably match on the transport/callback URL in the future, too.
  """
  def init_eventsub_subscriptions() do
    client_id = System.get_env("TWITCH_CLIENT_ID")
    access_token = get_access_token(client_id)

    case EventSub.Transports.WebHook.list_events(client_id, access_token) do
      {:ok, %{"data" => subscriptions}} ->
        eventsub_subscriptions()
        |> Stream.reject(fn {type, condition, version} ->
          Enum.any?(
            subscriptions,
            &match?(%{"type" => ^type, "condition" => ^condition, "version" => ^version}, &1)
          )
        end)
        |> Stream.map(&subscribe_mapper(access_token, client_id, &1))
        |> Enum.to_list()

      {:error, error} ->
        Logger.error("Could not list subscribed events from Twitch: #{inspect(error)}")
    end
  end

  def handle_eventsub_notif(%{"subscription" => %{"type" => "channel.update"}} = event, _details) do
    Logger.info("""
    #{event["event"]["broadcaster_user_name"]} updated their stream:
    category ID: #{event["event"]["category_id"]}
    category name: #{event["event"]["category_name"]}
    mature stream: #{event["event"]["is_mature"]}
    language: #{event["event"]["language"]}
    stream title: #{event["event"]["title"]}
    """)
  end

  def handle_eventsub_notif(
        %{
          "subscription" => %{"type" => "stream.online"},
          "event" => %{"broadcaster_user_id" => @pobsterlot_user_id}
        } = event,
        _details
      ) do
    Logger.info("Pob went live: #{inspect(event)}")
    Nostrum.Api.create_message(@bombad_general_channel_id, Enum.random(@new_stream_messages))
  end

  def handle_eventsub_notif(event, _details) do
    Logger.warning("unhandled eventsub notification received: #{inspect(event)}")
  end

  # fetch the token from the application env. If there is no token, request one from Twitch and put it in app env.
  # note: does not persist between app restarts
  defp get_access_token(client_id) do
    case Application.get_env(:pobcoin, :access_token, :none) do
      :none ->
        %{"access_token" => token, "expires_in" => expires_in_secs} =
          TwitchEx.OAuth.get_app_access_token(
            client_id,
            System.get_env("TWITCH_CLIENT_SECRET")
          )

        token_pair = {token, expires_in_secs + System.os_time(:second)}

        :ok = Application.put_env(:pobcoin, :access_token, token_pair, persistent: true)

        token

      {token, expires_at} ->
        if System.os_time(:second) > expires_at do
          Application.delete_env(:pobcoin, :access_token, persistent: true)
          get_access_token(client_id)
        else
          token
        end
    end
  end

  defp subscribe_mapper(access_token, client_id, {type, condition, version}) do
    access_token
    |> Subscription.new(client_id, condition, WebHook, type, version)
    |> WebHook.subscribe()
    |> case do
      {:ok, _} = ok ->
        ok

      {:error, error} ->
        Logger.error("""
        Could not subscribe to #{type} with condition #{inspect(condition)}, version #{version}
        Error: #{inspect(error)}
        """)

        {:error, error}
    end
  end
end
