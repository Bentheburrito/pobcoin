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
  oligarchs: [214_126_944_395_067_392, 254_728_052_070_678_529],
  guilds: [381_258_048_527_794_197, 850_929_434_437_746_690, 747_619_333_869_666_340]
