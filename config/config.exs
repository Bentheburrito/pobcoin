import Config

config :pobcoin, ecto_repos: [Pobcoin.Repo]

config :pobcoin, Pobcoin.Repo,
  database: "pobcoin",
  username: "postgres",
  password: "postgres",
  hostname: "localhost"
