import Config

config :pobcoin, ecto_repos: [Pobcoin.Repo]

config :pobcoin, Pobcoin.Repo,
  database: "pobcoin",
  username: "postgres",
  password: "postgres",
  hostname: "localhost"

config :pobcoin,
  oligarchs: [214126944395067392, 254728052070678529],
  guilds: [381258048527794197, 850929434437746690, 747619333869666340]
