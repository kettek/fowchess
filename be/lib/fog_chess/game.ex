defmodule FogChess.Cell do
  defstruct [:piece, :color]
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
    #^board = for x <- 0..7, into: board, do: {{x, 1}, %FogChess.Cell{piece: "pawn", color: "white"}}
    #board = for x <- 0..7, into: ^board, do: {{x, 6}, %FogChess.Cell{piece: "pawn", color: "black"}}
    #IO.inspect(board)
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

  def move(pid, player_id, from, to) do
    Agent.get(pid, fn(state) ->
      player = Map.get(state.players, player_id)
      case player do
        nil ->
          {:error, "no player"}
        _ ->
          with {:ok, fromCell} <- Map.fetch(state.cells, struct(FogChess.Cell, from)),
               {:ok, toCell} <- Map.fetch(state.cells, struct(FogChess.Cell, to)),
               {:ok, payload} <- Jason.encode(%{"from" => fromCell, "to" => toCell}) do
            send_to_allp(state, "data: #{payload}\n\n")
          end
      end
    end)
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
