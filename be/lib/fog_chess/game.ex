defmodule FogChess.Cell do
  @enforce_keys [:x, :y]
  defstruct [:x, :y]
end

defmodule FogChess.Game do
  @enforce_keys [:uuid]
  defstruct [:uuid, cells: %{}, players: %{}, turn: :white]

  @spec check_player(String.t()) :: none
  def check_player(player_uuid) do
    Map.has_key?(:players, player_uuid)
  end

  def players_turn(player_color) do
    case :turn do
      player_color -> {:ok, player_color}
      _ -> {:error, :wrong_turn}
    end
  end
end
