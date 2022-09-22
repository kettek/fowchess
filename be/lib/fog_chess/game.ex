defmodule FogChess.Cell do
  @enforce_keys [:x, :y]
  defstruct [:x, :y]
end

defmodule FogChess.PlayerConn do
  defstruct [:conn_pid]

  def send_update(payload) do
    send(:conn_pid, {:update, payload})
  end
end

defmodule FogChess.Game do
  use Agent

  defstruct [:uuid, :pid, cells: %{}, players: %{}, turn: :white]

  def start_link(game) do
    Agent.start_link(fn -> game end)
  end

  def set_pid(pid) do
    Agent.update(pid, fn(value) -> %{value | pid: pid} end)
  end

  def get(pid) do
    Agent.get(pid, fn(value) -> value end)
  end

  def put_player(pid, uuid, player_conn) do
    Agent.update(pid, fn(value) -> %{value | players: Enum.into(value.players, %{uuid => player_conn})} end)
  end

  def delete_player(pid, uuid) do
    Agent.update(pid, fn(value) -> %{value | players: Map.delete(value.players, uuid) } end)
  end

  #def check_player(pid, player_uuid) do
  #  Agent.get(pid, &Map.get(&1.players, player_uuid))
  #end

  #def players_turn(pid, player_color) do
  #  case Agent.get(pid, :turn) do
  #    player_color -> {:ok, player_color}
  #    _ -> {:error, :wrong_turn}
  #  end
  #end
end
