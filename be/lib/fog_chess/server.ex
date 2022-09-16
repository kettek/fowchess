defmodule FogChess.HttpRouter do
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

  # 404s, of course
  match _ do
    send_resp(conn, 404, "nothin here buddy")
  end
end
