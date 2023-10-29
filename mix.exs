defmodule Pobcoin.MixProject do
  use Mix.Project

  def project do
    [
      app: :pobcoin,
      version: "0.1.2",
      elixir: "~> 1.11",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {Pobcoin.Application, []},
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:nostrum, github: "Kraigie/nostrum"},
      # have to override this otherwise :tesla's gun dep version conflicts w/ nostrum
      {:gun, "== 2.0.1", [env: :prod, hex: "remedy_gun", repo: "hexpm", override: true]},
      {:ecto_sql, "~> 3.0"},
      {:postgrex, ">= 0.0.0"},
      {:dotenv_parser, "~> 1.2"},
      {:cowlib, "~> 2.11.1",
       [env: :prod, hex: "remedy_cowlib", repo: "hexpm", optional: false, override: true]},
      {:twitch_ex, "~> 0.1.0"}
    ]
  end
end
