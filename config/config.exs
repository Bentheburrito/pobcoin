import Config

config :pobcoin, ecto_repos: [Pobcoin.Repo]

config :pobcoin, Pobcoin.Repo,
  database: "pobcoin",
  username: "postgres",
  password: "postgres",
  hostname: "localhost"

config :pobcoin, :pobcoin_oligarchs, [214126944395067392, 254728052070678529]
