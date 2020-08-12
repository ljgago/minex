defmodule Minex.HTTP.Response do
  @moduledoc false

  @behaviour Access

  defstruct status_code: nil,
            headers: nil,
            data: nil

  @type t :: %__MODULE__{}

  def fetch(term, key), do: Map.fetch(term, key)

  def get_and_update(data, key, func) do
    Map.get_and_update(data, key, func)
  end

  def get(map, key, default), do: Map.get(map, key, default)

  def pop(data, key), do: Map.pop(data, key)
end
