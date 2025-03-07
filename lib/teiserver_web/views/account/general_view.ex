defmodule TeiserverWeb.Account.GeneralView do
  use TeiserverWeb, :view

  @spec view_colour :: atom
  def view_colour(), do: :success

  @spec icon() :: String.t()
  def icon(), do: "fa-solid fa-user"

  @spec view_colour(String.t()) :: atom
  def view_colour("profile"), do: :primary
  def view_colour("relationships"), do: :info
  def view_colour("customisation"), do: Central.Config.UserConfigLib.colours()
  def view_colour("preferences"), do: Central.Config.UserConfigLib.colours()
  def view_colour("clans"), do: Teiserver.Clans.ClanLib.colours()
end
