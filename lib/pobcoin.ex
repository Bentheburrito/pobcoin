defmodule Pobcoin do
  import Ecto.Query

  alias Pobcoin.{Repo, User}

  def pob_dollar_image_url,
    do:
      "https://cdn.discordapp.com/attachments/381258231613227020/850630598308921434/One_Pob_Dollar.png"

  def pob_purple, do: 0x651BC4

  def good_green, do: 0x20BA39

  def error_red, do: 0xD4223A

  def last_take_period_ms, do: 1000 * 60 * 20

  def last_sucked_period_ms,
    do:
      1000 *
        def(determine_one_percenters) do
    users =
      Repo.all(User)
      |> Enum.sort_by(fn %User{coins: coins} -> coins end, :desc)

    num_one_percenters = length(users) |> Kernel./(100) |> ceil()

    {one_percenters, poor_users} = Enum.split(users, num_one_percenters)

    one_percenters =
      one_percenters
      |> Enum.filter(&(&1.one_percenter == false))
      |> Enum.map(& &1.user_id)

    poor_users =
      poor_users
      |> Enum.filter(&(&1.one_percenter == true))
      |> Enum.map(& &1.user_id)

    from(u in User, where: u.user_id in ^one_percenters)
    |> Repo.update_all(set: [one_percenter: true])

    from(u in User, where: u.user_id in ^poor_users)
    |> Repo.update_all(set: [one_percenter: false])
  end
end
