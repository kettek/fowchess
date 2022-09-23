defmodule FogChess.HttpRouter do
  require Logger
  require UUID
  use Plug.Router

  # Debug because I don't know what I'm doing.
  plug Plug.Logger

  # Set up static files serving.
  plug Plug.Static,
    at: "/",
    from: "../fe"

  # Set up matching and dispatching...?
  plug :match
  # Set up post processing?
  plug Plug.Parsers,
    parsers: [:urlencoded, :json],
    json_decoder: Jason
  plug :dispatch

  # Send the index if the root is requested.
  get "/" do
    send_file(conn, 200, "../fe/index.html")
  end

  post "/auth" do
    if Map.has_key?(conn.body_params, "id") do
      conn
      |> send_resp(200, Jason.encode!(%{"id" => Map.get(conn.body_params, "id"), "ok" => "my liege"}))
    else
      conn
      |> send_resp(200, Jason.encode!(%{"id" => UUID.uuid4(), "ok" => "welcome to our lands"}))
    end
  end

  post "/game/create" do
    {:ok, pid} = FogChess.Game.start_link(FogChess.Game.new())
    FogChess.Game.set_pid(pid)
    FogChess.Games.put(FogChess.Game.get(pid).uuid, pid)
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(%{"ok" => "a new kingdom!", "id" => FogChess.Game.get(pid).uuid}))
  end

  get "/game/list" do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(FogChess.Games.list()))
  end

  get "/games/:id" do
    id = Map.get(conn.params, "id")
    gamePid = FogChess.Games.get(id)
    game = FogChess.Game.get(gamePid)
    case game do
      nil ->
        conn
        |> send_resp(404, Jason.encode!(%{"nok" => "no such game"}))
        _ ->
        conn
        |> send_resp(200, Jason.encode!(%{"ok" => "it exists!"}))
    end
  end

  patch "/games/:id/move" do
    player_id = Map.get(conn.body_params, "id")
    from = Map.get(conn.body_params, "from")
    to = Map.get(conn.body_params, "to")
    id = Map.get(conn.params, "id")
    gamePid = FogChess.Games.get(id)
    case gamePid do
      nil ->
        conn
        |> send_resp(404, Jason.encode!(%{"nok" => "invalid"}))
      _ ->
        case FogChess.Game.move(gamePid, player_id, from, to) do
          :ok ->
            conn
            |> send_resp(200, Jason.encode!(%{"ok" => "valid"}))
          :error ->
            conn
            |> send_resp(405, Jason.encode!(%{"nok" => "bad move"}))
          {:error, reason} ->
            conn
            |> send_resp(405, Jason.encode!(%{"nok" => reason}))
        end
    end
  end

  patch "/games/:id/untake" do
    player_id = Map.get(conn.body_params, "id")
    piece = Map.get(conn.body_params, "piece")
    color = Map.get(conn.body_params, "color")
    to = Map.get(conn.body_params, "to")
    gamePid = FogChess.Games.get(id)
    case gamePid do
      nil ->
        conn
        |> send_resp(404, Jason.encode!(%{"nok" => "invalid"}))
      _ ->
        case FogChess.Game.untake(gamePid, player_id, to, piece, color) do
          :ok ->
            conn
            |> send_resp(200, Jason.encode!(%{"ok" => "valid"}))
          :error ->
            conn
            |> send_resp(405, Jason.encode!(%{"nok" => "bad untake"}))
          {:error, reason} ->
            conn
            |> send_resp(405, Jason.encode!(%{"nok" => reason}))
        end
    end
  end

  get "/games/:id/stream" do
    player_uuid = Map.get(conn.query_params, "id")
    if player_uuid == nil do
      conn
      |> send_resp(401, "missing player id")
    else
      id = Map.get(conn.params, "id")
      game_pid = FogChess.Games.get(id)
      case game_pid do
        nil ->
          conn
          |> send_resp(404, "invalid game")
          _ ->
          FogChess.Game.put_player(game_pid, player_uuid, self())
          conn = conn
          |> put_resp_content_type("text/event-stream")
          |> put_resp_header("connection", "keep-alive")
          |> put_resp_header("cache-control", "no-cache")
          |> send_chunked(200)

          payload = Jason.encode!(FogChess.Game.board(game_pid))
          Plug.Conn.chunk(conn, "event: board\ndata: #{payload}\n\n")

          conn
          |> stream_loop(stream_watcher(self(), game_pid, player_uuid))
          #Plug.Conn.chunk(conn, "data: #{payload}\n\n")
      end
    end
  end

  defp stream_watcher(target, game_pid, player_uuid) do
    spawn(fn -> stream_watcher_loop(target, game_pid, player_uuid) end)
  end

  defp stream_watcher_loop(target, game_pid, player_uuid) do
    receive do
      {:tick} ->
        stream_watcher_loop(target, game_pid, player_uuid)
      after 2_000 ->
        FogChess.Game.delete_player(game_pid, player_uuid, target)
    end
  end

  defp stream_loop(conn, watcher_pid) do
    receive do
      {:update, payload} ->
        Plug.Conn.chunk(conn, payload)
        send(watcher_pid, {:tick})
        stream_loop(conn, watcher_pid)
      {:move} ->
        payload = Jason.encode!(%{"msg" => "secret message from beyond"})
        Plug.Conn.chunk(conn, "data: #{payload}\n\n")
        stream_loop(conn, watcher_pid)
      after 1_000 ->
        send(watcher_pid, {:tick})
        stream_loop(conn, watcher_pid)
        #payload = Jason.encode!(%{"msg" => "this is message ##{it}"})
        #case Plug.Conn.chunk(conn, "id: #{it}\ndata: #{payload}\n\n") do
        #  {:ok, conn} ->
        #    Logger.info("continue")
        #    stream_loop(conn, watcher_pid, it+1)
        #  {:error, reason} ->
        #    Logger.info(reason)
        #    {:halt, conn}
        #end
      end
  end

  # 404s, of course
  match _ do
    send_resp(conn, 404, "nothin here buddy")
  end
end
