defmodule FogChess.Games do
  use GenServer

  # Client

  def start_link(default) when is_map(default) do
    GenServer.start_link(__MODULE__, default, name: :games)
  end

  def get(uuid) do
    GenServer.call(:games, {:get, uuid})
  end

  def put(uuid, game) do
    GenServer.call(:games, {:put, uuid, game})
  end

  def delete(uuid) do
    GenServer.call(:games, {:delete, uuid})
  end

  # Server

  @impl true
  def init(games) do
    {:ok, games}
  end

  @impl true
  def handle_call({:get, uuid}, _from, state) do
    {:reply, Map.get(state, uuid), state}
  end

  @impl true
  def handle_call({:put, uuid, game}, _from, state) do
    {:reply, :ok, Map.put(state, uuid, game)}
  end

  @impl true
  def handle_call({:delete, uuid}, _from, state) do
    {:reply, :ok, Map.pop(state, uuid)}
  end
end
