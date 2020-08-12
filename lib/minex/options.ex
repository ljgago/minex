defmodule Minex.Options do
  @moduledoc false

  defstruct query: [],
            headers: []

  @type t :: %__MODULE__{
          query: [{binary(), binary()}],
          headers: [{binary(), binary()}]
        }

  @spec options_list_objects(t()) :: t()
  def options_list_objects(opts) do
    opts
  end
end
