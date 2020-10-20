defmodule Minex.S3.Options do
  @moduledoc false

  defstruct query: [],
            headers: []

  @type t :: %__MODULE__{
          query: [{binary(), binary()}],
          headers: [{binary(), binary()}]
        }
  @type options :: Minex.S3.Options.t()

  @spec options_list_objects(options(), binary(), true | false) :: options()
  def options_list_objects(opts, prefix, recursive) do
    query =
      [
        {"prefix", prefix},
        {"delimiter", get_delimiter(recursive)} | opts.query
      ]
      |> Enum.uniq_by(fn {key, _} -> key end)

    %Minex.S3.Options{
      query: query,
      headers: opts.headers
    }
  end

  defp get_delimiter(true), do: ""
  defp get_delimiter(false), do: "/"
end
