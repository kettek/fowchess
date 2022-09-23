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
        y == 1 ->
          {{x, y}, %FogChess.Cell{piece: "Pawn", color: "white"}}
        y == 0 && (x == 7 || x == 0) ->
          {{x, y}, %FogChess.Cell{piece: "Rook", color: "white"}}
        y == 0 && (x == 6 || x == 1) ->
          {{x, y}, %FogChess.Cell{piece: "Knight", color: "white"}}
        y == 0 && (x == 5 || x == 2) ->
          {{x, y}, %FogChess.Cell{piece: "Bishop", color: "white"}}
        y == 0 && x == 4 ->
          {{x, y}, %FogChess.Cell{piece: "Queen", color: "white"}}
        y == 0 && x == 3 ->
          {{x, y}, %FogChess.Cell{piece: "King", color: "white"}}
        y == 6 ->
          {{x, y}, %FogChess.Cell{piece: "Pawn", color: "black"}}
        y == 7 && (x == 7 || x == 0) ->
          {{x, y}, %FogChess.Cell{piece: "Rook", color: "black"}}
        y == 7 && (x == 6 || x == 1) ->
          {{x, y}, %FogChess.Cell{piece: "Knight", color: "black"}}
        y == 7 && (x == 5 || x == 2) ->
          {{x, y}, %FogChess.Cell{piece: "Bishop", color: "black"}}
        y == 7 && x == 4 ->
          {{x, y}, %FogChess.Cell{piece: "Queen", color: "black"}}
        y == 7 && x == 3 ->
          {{x, y}, %FogChess.Cell{piece: "King", color: "black"}}
        true ->
          {{x, y}, %FogChess.Cell{}}
      end
    end
    board
  end
end

defmodule FogChess.PlayerConn do
  require Logger
  defstruct [:pids]

  def send_update(player, payload) do
    Enum.each(player.pids, fn pid ->
      send(pid, {:update, payload})
    end)
  end
end


defmodule FogChess.Tray do
  def get_piece(tray, piece, color) do
    Enum.find(tray, nil, fn p -> p.piece == piece && p.color == color end)
  end

  def remove_piece(tray, piece, color) do
    if get_piece(tray, piece, color) do
      Enum.filter(tray, fn p -> p.piece == piece && p.color == color end)
    else
      tray
    end
  end
end

defmodule FogChess.Game do
  use Agent

  defstruct [:uuid, :pid, :name, cells: %{}, players: %{}, turn: :white, tray: []]

  def new() do
    %FogChess.Game{
      name: "",
      uuid: UUID.uuid4(),
      cells: FogChess.Board.make_chess(),
      tray: [],
    }
  end

  def start_link(game) do
    Agent.start_link(fn -> game end)
  end

  def set_pid(pid) do
    Agent.update(pid, fn(state) -> %{state | pid: pid} end)
  end

  def get(pid) do
    Agent.get(pid, fn(state) -> state end)
  end

  def board(pid) do
    Agent.get(pid, fn(state) ->
      state.cells
      |> Enum.filter(fn {_, v} -> v.piece != nil end)
      |> Enum.map(fn({{x, y}, cell}) ->
        Map.merge(%{x: x, y: y}, Map.from_struct(cell))
      end)
    end)
  end

  def tray(pid) do
     Agent.get(pid, fn(state) ->
      Enum.map(state.tray, fn piece -> Map.from_struct(piece) end)
    end)
  end

  def put_player(pid, uuid, player_pid) do
    Agent.update(pid, fn(state) ->
      case Map.get(state.players, uuid) do
        nil -> Map.put(state, :players, Map.put(state.players, uuid, %FogChess.PlayerConn{pids: [player_pid]}))
        player -> Map.put(state, :players, Map.put(state.players, uuid, %FogChess.PlayerConn{player | pids: [player_pid | player.pids]}))
      end
    end)
  end

  @spec delete_player(atom | pid | {atom, any} | {:via, atom, any}, any, any) :: :ok
  def delete_player(pid, uuid, player_pid) do
    Agent.update(pid, fn(state) ->
      case Map.get(state.players, uuid) do
        nil -> state
        player when length(player.pids) == 1 -> Map.put(state, :players, Map.delete(state.players, uuid))
        player -> Map.put(state, :players, Map.put(state.players, uuid, %FogChess.PlayerConn{ player | pids: Enum.filter(player.pids, fn p -> p != player_pid end)}))
      end
    end)
  end

  def send_to_all(pid, payload) do
    Agent.get(pid, fn(state) ->
      Enum.each(state.players, fn {_uuid, player} ->
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
               {:ok, to_cell} <- get_cell(state.cells, to_x, to_y)
          do
            #cond do
            #  {:ok, state} = move_(state, {from_x, from_y}, from_cell, {to_x, to_y}, to_cell) ->
            #    {:ok, payload} = Jason.encode(%{"from" => from, "to" => to})
            #    send_to_allp(state, "event: move\ndata: #{payload}\n\n")
            #    IO.inspect(state)
            #    {:ok, state}
            #  {:ok, state} = take_(state, {from_x, from_y}, from_cell, {to_x, to_y}, to_cell) ->
            #    {:ok, payload} = Jason.encode(%{"from" => from, "to" => to})
            #    send_to_allp(state, "event: take\ndata: #{payload}\n\n")
            #    {:ok, state}
            #  true ->
            #    IO.puts("oh")
            #    {:error, state}
            #end

            case move_(state, {from_x, from_y}, from_cell, {to_x, to_y}, to_cell) do
              {:ok, state} ->
                {:ok, payload} = Jason.encode(%{"from" => from, "to" => to})
                send_to_allp(state, "event: move\ndata: #{payload}\n\n")
                IO.inspect(state)
                {:ok, state}
              _ ->
                case take_(state, {from_x, from_y}, from_cell, {to_x, to_y}, to_cell) do
                  {:ok, state} ->
                    {:ok, payload} = Jason.encode(%{"from" => from, "to" => to})
                    send_to_allp(state, "event: take\ndata: #{payload}\n\n")
                    {:ok, state}
                  _ ->
                    IO.puts("oh")
                    {:error, state}
                end
            end
          else
            false -> {{:error, :nonempty_cell}, state}
            {:error, :invalid_cell} -> {{:error, :invalid_cell}, state}
          end
#      end
    end)
  end

  def untake(pid, _player_id, to, piece, color) do
    Agent.get_and_update(pid, fn(state) ->
      {to_x, to_y} = {String.to_integer(to["x"]), String.to_integer(to["y"])}
      with {:ok, to_cell} <- get_cell(state.cells, to_x, to_y),
           true <- FogChess.Cell.is_empty(to_cell) do
        with {:ok, payload} <- Jason.encode(%{"to" => to, "piece" => piece, "color" => color}) do
          send_to_allp(state, "event: untake\ndata: #{payload}\n\n")
          state = Map.put(state, :tray, FogChess.Tray.remove_piece(state.tray, piece, color))
          |> Map.put(:cells,
            Map.put(state.cells, {to_x, to_y}, %FogChess.Cell{piece: piece, color: color})
          )
          {:ok, state}
        end
      else
        false -> {{:error, :nonempty_cell}, state}
        {:error, :invalid_cell} -> {{:error, :invalid_cell}, state}
      end
    end)
  end

  defp take_(state, from, from_cell, to, to_cell) do
    if FogChess.Cell.is_empty(to_cell) do
      IO.puts("no take_")
      {:nok, state}
    else
      IO.puts("take_")
      {:ok, state
        |> Map.put(:tray, [to_cell | state.tray])
        |> Map.put(:cells, Map.put(state.cells, from, %FogChess.Cell{}) |> Map.put(to, from_cell))
      }
    end
  end

  defp move_(state, from, from_cell, to, to_cell) do
    if FogChess.Cell.is_empty(to_cell) do
      IO.puts("move_")
      {:ok, state
        |> Map.put(:cells, Map.put(state.cells, from, %FogChess.Cell{}) |> Map.put(to, from_cell))
      }
    else
      IO.puts("no move_")
      {:nok, state}
    end
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
