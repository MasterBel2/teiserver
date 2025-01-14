defmodule TeiserverWeb.Battle.LobbyLive.Index do
  use TeiserverWeb, :live_view
  alias Phoenix.PubSub

  alias Teiserver
  alias Teiserver.Battle.Lobby
  alias Teiserver.Battle.LobbyLib

  @extra_menu_content """
  &nbsp;&nbsp;&nbsp;
    <a href='/teiserver/admin/client' class="btn btn-outline-primary">
      <i class="fa-solid fa-fw fa-plug"></i>
      Clients
    </a>
  """

  @impl true
  def mount(_params, session, socket) do
    socket =
      socket
      |> AuthPlug.live_call(session)
      |> TSAuthPlug.live_call(session)
      |> NotificationPlug.live_call()

    extra_content = if allow?(socket, "teiserver.moderator.account") do
      @extra_menu_content
    end

    socket = socket
      |> add_breadcrumb(name: "Teiserver", url: "/teiserver")
      |> add_breadcrumb(name: "Battles", url: "/teiserver/battle/lobbies")
      |> assign(:site_menu_active, "teiserver_lobbies")
      |> assign(:view_colour, LobbyLib.colours())
      |> assign(:battles, Lobby.list_lobbies() |> sort_lobbies)
      |> assign(:menu_override, Routes.ts_general_general_path(socket, :index))
      |> assign(:extra_menu_content, extra_content)

    {:ok, socket, layout: {CentralWeb.LayoutView, "standard_live.html"}}
  end

  @impl true
  def handle_params(_, _, %{assigns: %{current_user: nil}} = socket) do
    {:noreply, socket |> redirect(to: Routes.general_page_path(socket, :index))}
  end

  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  @impl true
  def handle_info({:global_battle_updated, lobby_id, :battle_opened}, socket) do
    new_battle = Lobby.get_battle(lobby_id)
    battles = [new_battle | socket.assigns[:battles]]
    |> sort_lobbies

    {:noreply, assign(socket, :battles, battles)}
  end

  def handle_info({:global_battle_updated, lobby_id, :battle_closed}, socket) do
    battles =
      socket.assigns[:battles]
      |> Enum.filter(fn b -> b.id != lobby_id end)
    |> sort_lobbies

    {:noreply, assign(socket, :battles, battles)}
  end

  def handle_info({:global_battle_updated, lobby_id, _reason}, socket) do
    battles =
      socket.assigns[:battles]
      |> Enum.map(fn battle ->
        if battle.id == lobby_id do
          Lobby.get_battle(lobby_id)
        else
          battle
        end
      end)
    |> sort_lobbies

    {:noreply, assign(socket, :battles, battles)}
  end

  def handle_info({:add_user_to_battle, user_id, lobby_id, _script_password}, socket) do
    battles =
      socket.assigns[:battles]
      |> Enum.map(fn battle ->
        if battle.id == lobby_id do
          %{battle | member_count: Enum.count([user_id | battle.players]), players: [user_id | battle.players]}
        else
          battle
        end
      end)
    |> sort_lobbies

    {:noreply, assign(socket, :battles, battles)}
  end

  def handle_info({:remove_user_from_battle, user_id, lobby_id}, socket) do
    battles =
      socket.assigns[:battles]
      |> Enum.map(fn battle ->
        if battle.id == lobby_id do
          new_players = Enum.filter(battle.players, fn p -> p != user_id end)
          %{battle | member_count: Enum.count(new_players), players: new_players}
        else
          battle
        end
      end)
    |> sort_lobbies

    {:noreply, assign(socket, :battles, battles)}
  end

  def handle_info({:kick_user_from_battle, user_id, lobby_id}, socket) do
    battles =
      socket.assigns[:battles]
      |> Enum.map(fn battle ->
        if battle.id == lobby_id do
          new_players = Enum.filter(battle.players, fn p -> p != user_id end)
          %{battle | member_count: Enum.count(new_players), players: new_players}
        else
          battle
        end
      end)
    |> sort_lobbies

    {:noreply, assign(socket, :battles, battles)}
  end

  defp sort_lobbies(lobbies) do
    lobbies
      |> Enum.sort_by(
        fn v -> {v.locked, v.password != nil, -v.member_count, v.name} end,
        &<=/2
      )

      # |> Enum.sort_by(fn v -> v end, &<=/2)
  end

  defp apply_action(socket, :index, _params) do
    :ok = PubSub.subscribe(Central.PubSub, "legacy_all_battle_updates")

    socket
    |> assign(:page_title, "Listing Battles")
    |> assign(:battle, nil)
  end
end
