defmodule Game do
  @enforce_keys [:uuid]
  defstruct [:uuid, connections: []]
end
