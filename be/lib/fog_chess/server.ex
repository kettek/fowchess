defmodule FogChess.HttpRouter do
  require Logger
  use Plug.Router

  # Debug because I don't know what I'm doing.
  plug Plug.Logger

  # Set up static files serving.
  plug Plug.Static,
    at: "/",
    from: "../fe"

  # Set up matching and dispatching...?
  plug :match
  plug :dispatch

  # Send the index if the root is requested.
  get "/" do
    send_file(conn, 200, "../fe/index.html")
  end

  get "/game/:id" do
    send_resp(conn, 200, "TODO: query for game, make it if it doesn't, then send game info along with a session key for the client")
  end

  get "/stream" do
    conn
    |> put_resp_content_type("text/event-stream")
    |> put_resp_header("connection", "keep-alive")
    |> put_resp_header("cache-control", "no-cache")
    |> send_chunked(200)
    |> stream_loop(0)
  end

  defp stream_loop(conn, it) do
    case it do
      5 ->
        payload = Jason.encode!(%{"msg" => "bye bye on message #{it}"})
        Plug.Conn.chunk(conn, "id: #{it}\nevent: exit\ndata: #{payload}}\n\n")
        conn
      _ ->
        receive do
          {:move} ->
            payload = Jason.encode!(%{"msg" => "secret message from beyond"})
            Plug.Conn.chunk(conn, "id: #{it}\ndata: #{payload}\n\n")
            stream_loop(conn, it+1)
          after 1_000 ->
            payload = Jason.encode!(%{"msg" => "this is message ##{it}"})
            Plug.Conn.chunk(conn, "id: #{it}\ndata: #{payload}\n\n")
            stream_loop(conn, it+1)
          end
    end
  end

  # 404s, of course
  match _ do
    send_resp(conn, 404, "nothin here buddy")
  end
end
