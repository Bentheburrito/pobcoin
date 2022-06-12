import Config

config :pobcoin, ecto_repos: [Pobcoin.Repo]

config :nostrum,
  token: System.get_env("BOT_TOKEN")

config :pobcoin, Pobcoin.Repo,
  database: "pobcoin",
  username: "postgres",
  password: System.get_env("DB_PASS") || "postgres",
  hostname: "localhost"

config :pobcoin,
  oligarchs: [214126944395067392, 254728052070678529],
  guilds: [381258048527794197, 850929434437746690, 747619333869666340]
