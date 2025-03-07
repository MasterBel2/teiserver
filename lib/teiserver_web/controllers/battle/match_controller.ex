defmodule TeiserverWeb.Battle.MatchController do
  use CentralWeb, :controller

  alias Teiserver.Battle
  # alias Teiserver.Battle.Match
  alias Teiserver.Battle.MatchLib

  plug Bodyguard.Plug.Authorize,
    policy: Teiserver.Battle.Match,
    action: {Phoenix.Controller, :action_name},
    user: {Central.Account.AuthLib, :current_user}

  plug(AssignPlug,
    site_menu_active: "teiserver_match",
    sub_menu_active: "match"
  )

  plug :add_breadcrumb, name: 'Battle', url: '/teiserver'
  plug :add_breadcrumb, name: 'Logs', url: '/teiserver/matches'

  @spec index(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def index(conn, _params) do
    matches = if false and allow?(conn, "teiserver.moderator") do
      Battle.list_matches(
        search: [
          processed: true
        ],
        order_by: "Newest first"
      )
    else
      memberships = Battle.list_match_memberships(search: [user_id: conn.user_id], select: [:match_id])
      |> Enum.map(fn mm -> mm.match_id end)

      Battle.list_matches(
        search: [
          processed: true,
          id_list: memberships
        ],
        order_by: "Newest first"
      )
    end

    conn
    |> assign(:matches, matches)
    |> render("index.html")
  end

  @spec show(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def show(conn, %{"id" => id}) do
    match = Battle.get_match!(id, [
      preload: [:members_and_users],
    ])

    match
    |> MatchLib.make_favourite
    |> insert_recently(conn)

    match_name = MatchLib.make_match_name(match)

    members = match.members
      |> Enum.sort_by(fn m -> m.user.name end, &<=/2)
      |> Enum.sort_by(fn m -> m.team_id end, &<=/2)

    conn
    |> assign(:match, match)
    |> assign(:match_name, match_name)
    |> assign(:members, members)
    |> add_breadcrumb(name: "Show: #{match_name}", url: conn.request_path)
    |> render("show.html")
  end

  @spec delete(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def delete(conn, %{"id" => id}) do
    match = Battle.get_match!(id)

    match
    |> MatchLib.make_favourite
    |> remove_recently(conn)

    {:ok, _match} = Battle.delete_match(match)

    conn
    |> put_flash(:info, "Match deleted successfully.")
    |> redirect(to: Routes.ts_battle_match_path(conn, :index))
  end
end
