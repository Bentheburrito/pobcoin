defmodule Pobcoin do
  import Ecto.Query

  alias Pobcoin.{Repo, User}

  def pob_dollar_image_url, do: "https://cdn.discordapp.com/attachments/381258231613227020/850630598308921434/One_Pob_Dollar.png"

  def pob_purple, do: 0x651bc4

  def good_green, do: 0x20ba39

  def error_red, do: 0xd4223a

  def determine_one_percenters do
    users =
      Repo.all(User)
      |> Enum.sort_by(fn %User{coins: coins} -> coins end, :desc)

    num_one_percenters = length(users) |> Kernel./(100) |> ceil()

    one_percenters =
      Enum.take(users, num_one_percenters)
      |> Enum.map(&(&1.user_id))

    from(u in User, where: u.user_id in ^one_percenters)
    |> Repo.update_all(set: [one_percenter: true])
  end
end
