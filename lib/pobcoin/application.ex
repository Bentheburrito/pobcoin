defmodule Pobcoin.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      Pobcoin.Repo,
      SlashCommand,
      Pobcoin.GuessWhoHandler,
      Pobcoin.PredictionHandler.WagerSelections,
      Pobcoin.PredictionHandler,
      {Pobcoin.Consumer, name: Pobcoin.Consumer}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Pobcoin.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
