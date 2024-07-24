import Config

if Config.config_env() == :dev do
  DotenvParser.load_file(".env")
end

config :nostrum,
  token: System.get_env("BOT_TOKEN")

case System.get_env("DB_SOCKET") do
  nil ->
    config :pobcoin, Pobcoin.Repo,
      database: "pobcoin",
      username: System.get_env("DB_USER"),
      password: System.get_env("DB_PASS"),
      hostname: System.get_env("DB_HOST")

  socket ->
    config :pobcoin, Pobcoin.Repo,
      database: "pobcoin",
      username: System.get_env("DB_USER"),
      socket_dir: socket
end
