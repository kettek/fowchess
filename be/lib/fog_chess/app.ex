defmodule FogChess.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Plug.Cowboy, scheme: :http, plug: FogChess.HttpRouter, options: [port: 4000]},
      {FogChess.Games, %{}}
    ]

    opts = [strategy: :one_for_one, name: FogChess.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
