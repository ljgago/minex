defmodule Minex.HTTP.Adapter do
  @moduledoc false

  alias Minex.HTTP

  @type request :: HTTP.Request.t()

  @callback init(config :: any()) :: {:ok, tuple()}
  @callback start_link(opts :: keyword()) :: any()
  @callback request(req :: request()) :: any()
  @callback request_filestream(req :: request(), file_path :: binary(), file_opts :: list()) :: any()
end
