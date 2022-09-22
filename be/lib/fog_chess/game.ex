defmodule FogChess.Cell do
  defstruct [:piece, :color]

  def is_empty(cell) do
    Map.get(cell, :piece) == nil
  end
end

defmodule FogChess.Board do
  def make_chess() do
    board = for x <- 0..7, y <- 0..7, into: %{} do
      cond do
        y == 0 && (x == 7 || x == 0) ->
          {{x, y}, %FogChess.Cell{piece: "Rook", color: "white"}}
        y == 1 ->
          {{x, y}, %FogChess.Cell{piece: "Pawn", color: "white"}}
        y == 6 ->
          {{x, y}, %FogChess.Cell{piece: "Pawn", color: "black"}}
        y == 7 && (x == 7 || x == 0) ->
          {{x, y}, %FogChess.Cell{piece: "Rook", color: "black"}}
        true ->
          {{x, y}, %FogChess.Cell{}}
      end
    end
    board
  end
end

defmodule FogChess.PlayerConn do
  require Logger
  defstruct [:conn_pid]

  def send_update(player, payload) do
    send(player.conn_pid, {:update, payload})
  end
end

defmodule FogChess.Game do
  use Agent

  defstruct [:uuid, :pid, cells: %{}, players: %{}, turn: :white]

  def new() do
    %FogChess.Game{
      uuid: UUID.uuid4(),
      cells: FogChess.Board.make_chess(),
    }
  end

  def start_link(game) do
    Agent.start_link(fn -> game end)
  end

  def set_pid(pid) do
    Agent.update(pid, fn(value) -> %{value | pid: pid} end)
  end

  def get(pid) do
    Agent.get(pid, fn(value) -> value end)
  end

  def board(pid) do
    Agent.get(pid, fn(value) ->
      value.cells
      |> Enum.filter(fn {_, v} -> v.piece != nil end)
      |> Enum.map(fn({{x, y}, cell}) ->
        Map.merge(%{x: x, y: y}, Map.from_struct(cell))
      end)
    end)
  end

  def put_player(pid, uuid, player_conn) do
    Agent.update(pid, fn(value) -> %{value | players: Enum.into(value.players, %{uuid => player_conn})} end)
  end

  def delete_player(pid, uuid) do
    Agent.update(pid, fn(value) -> %{value | players: Map.delete(value.players, uuid) } end)
  end

  def send_to_all(pid, payload) do
    Agent.get(pid, fn(value) ->
      Enum.each(value.players, fn {uuid, player} ->
        FogChess.PlayerConn.send_update(player, payload)
      end)
    end)
  end

  defp send_to_allp(state, payload) do
    Enum.each(state.players, fn {_, player} ->
      FogChess.PlayerConn.send_update(player, payload)
    end)
    :ok
  end

  def move(pid, _player_id, from, to) do
    Agent.get_and_update(pid, fn(state) ->
#      player = Map.get(state.players, player_id)
#      case player do
#        nil ->
#          {:error, "no player"}
#        _ ->
          {from_x, from_y} = {String.to_integer(from["x"]), String.to_integer(from["y"])}
          {to_x, to_y} = {String.to_integer(to["x"]), String.to_integer(to["y"])}
          with {:ok, from_cell} <- get_cell(state.cells, from_x, from_y),
               {:ok, to_cell} <- get_cell(state.cells, to_x, to_y),
               true <- FogChess.Cell.is_empty(to_cell)
          do
            with {:ok, payload} <- Jason.encode(%{"from" => from, "to" => to})
            do
              send_to_allp(state, "event: move\ndata: #{payload}\n\n")
              state = Map.put(state, :cells,
                Map.put(state.cells, {from_x, from_y}, %FogChess.Cell{})
                |> Map.put({to_x, to_y}, from_cell)
              )
              {:ok, state}
            end
          else
            false -> {{:error, :nonempty_cell}, state}
            {:error, :invalid_cell} -> {{:error, :invalid_cell}, state}
          end
#      end
    end)
  end

  defp get_cell(cells, x, y) do
    case Map.fetch(cells, {x, y}) do
      {:ok, cell} -> {:ok, cell}
      :error -> {:error, :invalid_cell}
    end
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
