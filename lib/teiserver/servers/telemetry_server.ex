defmodule Teiserver.Telemetry.TelemetryServer do
  use GenServer
  alias Teiserver.Battle.Lobby
  alias Teiserver.Client
  require Logger
  alias Phoenix.PubSub

  @client_states ~w(lobby menu player spectator total)a
  @tick_period 9_000
  @counters ~w(matches_started matches_stopped users_connected users_disconnected bots_connected bots_disconnected)a
  @default_state %{
    counters: Map.new(@counters, fn c -> {c, 0} end),
    client: %{
      player: [],
      spectator: [],
      lobby: [],
      menu: []
    },
    battle: %{
      total: 0,
      lobby: 0,
      in_progress: 0,

      # Battles completed as part of this tick, not a cumulative total
      # reset when the reset command is sent
      completed: 0
    },
    matchmaking: %{

    },
    server: %{
      users_connected: 0,
      users_disconnected: 0,

      bots_connected: 0,
      bots_disconnected: 0,

      load: 0,
    }
  }

  @impl true
  def handle_info(:tick, state) do
    totals = get_totals(state)
    report_telemetry(totals)

    {:noreply, state}
  end

  def handle_info({:increment, counter}, state) do
    current = Map.get(state.counters, counter, 0)
    new_counters = Map.put(state.counters, counter, current + 1)
    {:noreply, %{state | counters: new_counters}}
  end

  @impl true
  def handle_cast({:matchmaking_update, queue_id, data}, %{matchmaking: matchmaking} = state) do
    new_matchmaking = Map.put(matchmaking, queue_id, data)
    {:noreply, %{state | matchmaking: new_matchmaking}}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  def handle_call(:get_totals_and_reset, _from, state) do
    {:reply, get_totals(state), @default_state}
  end

  @spec report_telemetry(Map.t()) :: :ok
  defp report_telemetry(state) do
    client = @client_states
    |> Map.new(fn cstate ->
      {cstate, state.client[cstate] |> Enum.count}
    end)

    :telemetry.execute([:teiserver, :client], client, %{})
    :telemetry.execute([:teiserver, :battle], state.battle, %{})

    # TODO: Is there a way to hook into the above data for our liveviews?
    PubSub.broadcast(
      Central.PubSub,
      "teiserver_telemetry",
      {:teiserver_telemetry, %{
        client: client,
        battle: state.battle
      }}
    )
  end

  @spec get_totals(Map.t()) :: Map.t()
  defp get_totals(state) do
    battles = Lobby.list_lobbies()
    client_ids = Client.list_client_ids()
    clients = client_ids
      |> Map.new(fn c -> {c, Client.get_client_by_id(c)} end)

    # Battle stats
    total_battles = Enum.count(battles)
    battles_in_progress = battles
    |> Enum.filter(fn battle ->
        # If the host is in-game, the battle is in progress!
        host = clients[battle.founder_id]
        host != nil and host.in_game
      end)

    # Client stats
    {player_ids, spectator_ids, lobby_ids, menu_ids} = clients
      |> Enum.reduce({[], [], [], []}, fn ({userid, client}, {player, spectator, lobby, menu}) ->
        add_to = cond do
          client == nil -> nil
          client.bot == true -> nil
          client.lobby_id == nil -> :menu

          # Client is involved in a battle in some way
          # In this case they are not in a game, they are in a battle lobby
          client.in_game == false -> :lobby

          # User is in a game, are they a player or a spectator?
          client.player == false -> :spectator
          client.player == true -> :player
        end

        case add_to do
          nil -> {player, spectator, lobby, menu}
          :player -> {[userid | player], spectator, lobby, menu}
          :spectator -> {player, [userid | spectator], lobby, menu}
          :lobby -> {player, spectator, [userid | lobby], menu}
          :menu -> {player, spectator, lobby, [userid | menu]}
        end
      end)

    counters = state.counters

    %{
      client: %{
        player: player_ids,
        spectator: spectator_ids,
        lobby: lobby_ids,
        menu: menu_ids,
        total: Enum.uniq(player_ids ++ spectator_ids ++ lobby_ids ++ menu_ids)
      },
      battle: %{
        total: total_battles,
        lobby: total_battles - Enum.count(battles_in_progress),
        in_progress: Enum.count(battles_in_progress),
        started: counters.matches_started,
        stopped: counters.matches_stopped,
      },
      matchmaking: %{

      },
      server: %{
        users_connected: counters.users_connected,
        users_disconnected: counters.users_disconnected,

        bots_connected: counters.bots_connected,
        bots_disconnected: counters.bots_disconnected
      },
      os_mon: get_os_mon_data()
    }
  end

  @spec get_os_mon_data :: map()
  def get_os_mon_data() do
    # cpu_per_core =
    #   case :cpu_sup.util([:detailed, :per_cpu]) do
    #     {:all, 0, 0, []} -> []
    #     cores -> Enum.map(cores, fn {n, busy, non_b, _} -> {n, Map.new(busy ++ non_b)} end)
    #   end

    # disk =
    #   case :disksup.get_disk_data() do
    #     [{'none', 0, 0}] -> []
    #     other -> other
    #   end

    %{
      cpu_avg1: :cpu_sup.avg1(),
      cpu_avg5: :cpu_sup.avg5(),
      cpu_avg15: :cpu_sup.avg15(),
      cpu_nprocs: :cpu_sup.nprocs(),
      # cpu_per_core: cpu_per_core |> Map.new(),
      # disk: disk |> Map.new(),
      system_mem: :memsup.get_system_memory_data() |> Map.new()
    }
  end

  defp reset_state(state) do
    Map.merge(@default_state, Map.take(state, [:counters]))
  end

  # Startup
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts[:data], opts)
  end

  @impl true
  def init(_opts) do
    :timer.send_interval(@tick_period, self(), :tick)

    {:ok, reset_state(%{})}
  end
end
