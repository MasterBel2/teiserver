# A struct representing the in-memory version of Teiserver.Game.DBQueue
defmodule Teiserver.Data.QueueStruct do
  @enforce_keys [:id, :name, :team_size, :icon, :colour, :settings, :conditions, :map_list]
  defstruct [
    :id,
    :name,
    :team_size,
    :icon,
    :colour,
    :settings,
    :conditions,
    :map_list,
    current_search_time: 0,
    current_size: 0,
    contents: []
  ]
end

defmodule Teiserver.Data.Matchmaking do
  require Logger
  alias Teiserver.Game
  alias Teiserver.Data.QueueStruct
  alias Teiserver.Game.{QueueWaitServer, QueueMatchServer}
  alias Teiserver.Data.Types, as: T

  @spec get_queue(Integer.t()) :: QueueStruct.t() | nil
  def get_queue(id) do
    Central.cache_get(:teiserver_queues, id)
  end

  @spec get_queue_wait_pid(integer) :: pid() | nil
  def get_queue_wait_pid(id) when is_integer(id) do
    case Horde.Registry.lookup(Teiserver.ServerRegistry, "QueueWaitServer:#{id}") do
      [{pid, _}] ->
        pid
      _ ->
        nil
    end
  end

  @spec call_queue_wait(Integer.t(), any) :: any
  def call_queue_wait(id, msg) do
    pid = get_queue_wait_pid(id)
    GenServer.call(pid, msg)
  end

  @spec cast_queue_wait(Integer.t(), any) :: any
  def cast_queue_wait(id, msg) do
    pid = get_queue_wait_pid(id)
    GenServer.cast(pid, msg)
  end

  @spec get_queue_match_pid(String.t()) :: pid() | nil
  def get_queue_match_pid(id) do
    case Horde.Registry.lookup(Teiserver.ServerRegistry, "QueueMatchServer:#{id}") do
      [{pid, _}] ->
        pid
      _ ->
        nil
    end
  end

  @spec call_queue_match(String.t(), any) :: any
  def call_queue_match(id, msg) do
    pid = get_queue_match_pid(id)
    GenServer.call(pid, msg)
  end

  @spec cast_queue_match(String.t(), any) :: any
  def cast_queue_match(id, msg) do
    pid = get_queue_match_pid(id)
    GenServer.cast(pid, msg)
  end

  @spec add_match_server(T.queue_id(), list()) :: pid
  def add_match_server(queue_id, members) do
    match_id = UUID.uuid1()

    {:ok, pid} = DynamicSupervisor.start_child(Teiserver.Game.QueueSupervisor, {
      QueueMatchServer,
      data: %{
        match_id: match_id,
        queue_id: queue_id,
        members: members
      }
    })

    pid
  end

  @spec get_queue_and_info(Integer.t()) :: {QueueStruct.t(), Map.t()}
  def get_queue_and_info(id) when is_integer(id) do
    queue = Central.cache_get(:teiserver_queues, id)
    info = call_queue_wait(id, :get_info)
    {queue, info}
  end

  @spec add_queue(QueueStruct.t()) :: :ok
  def add_queue(queue) do
    Central.cache_update(:lists, :queues, fn value ->
      new_value =
        ([queue.id | value])
        |> Enum.uniq()

      {:ok, new_value}
    end)

    DynamicSupervisor.start_child(Teiserver.Game.QueueSupervisor, {
      QueueWaitServer,
      data: %{queue: queue}
    })
    update_queue(queue)
  end

  @spec update_queue(QueueStruct.t()) :: :ok
  def update_queue(queue) do
    Central.cache_put(:teiserver_queues, queue.id, queue)
  end

  @spec list_queues :: [QueueStruct.t() | nil]
  def list_queues() do
    Central.cache_get(:lists, :queues)
    |> Enum.map(fn queue_id -> Central.cache_get(:teiserver_queues, queue_id) end)
  end

  @spec list_queues([Integer.t()]) :: [QueueStruct.t() | nil]
  def list_queues(id_list) do
    id_list
    |> Enum.map(fn queue_id ->
      Central.cache_get(:teiserver_queues, queue_id)
    end)
  end

  @spec add_player_to_queue(Integer.t(), Integer.t()) :: :ok | :duplicate | :failed
  def add_player_to_queue(queue_id, player_id) do
    case get_queue_wait_pid(queue_id) do
      nil ->
        :failed

      pid ->
        GenServer.call(pid, {:add_player, player_id})
    end
  end

  @spec remove_player_from_queue(Integer.t(), Integer.t()) :: :ok | :missing
  def remove_player_from_queue(queue_id, player_id) do
    case get_queue_wait_pid(queue_id) do
      nil ->
        :failed

      pid ->
        GenServer.call(pid, {:remove_player, player_id})
    end
  end

  @spec player_accept(Integer.t(), Integer.t()) :: :ok | :missing
  def player_accept(queue_id, player_id) do
    case get_queue_wait_pid(queue_id) do
      nil ->
        :failed

      pid ->
        GenServer.cast(pid, {:player_accept, player_id})
        :ok
    end
  end

  @spec player_decline(Integer.t(), Integer.t()) :: :ok | :missing
  def player_decline(queue_id, player_id) do
    case get_queue_wait_pid(queue_id) do
      nil ->
        :failed

      pid ->
        GenServer.cast(pid, {:player_decline, player_id})
        :ok
    end
  end

  @spec add_queue_from_db(Map.t()) :: :ok
  def add_queue_from_db(queue) do
    convert_queue(queue)
    |> add_queue()
  end

  def refresh_queue_from_db(queue) do
    cast_queue_wait(queue.id, {:refresh_from_db, queue})
  end

  @spec convert_queue(Game.Queue.t()) :: QueueStruct.t()
  defp convert_queue(queue) do
    %QueueStruct{
      id: queue.id,
      name: queue.name,
      team_size: queue.team_size,
      icon: queue.icon,
      colour: queue.colour,
      settings: queue.settings,
      conditions: queue.conditions,
      map_list: queue.map_list
    }
  end

  @spec pre_cache_queues :: :ok
  def pre_cache_queues() do
    Central.cache_insert_new(:lists, :queues, [])

    queue_count =
      Game.list_queues(limit: :infinity)
      |> Parallel.map(fn queue ->
        queue
        |> convert_queue
        |> add_queue
      end)
      |> Enum.count()

    Logger.info("pre_cache_queues, got #{queue_count} queues")
  end
end
