defmodule Minex.HTTP.Adapter do
  alias Minex.HTTP

  @type request :: HTTP.Request.t()

  @callback start_link(opts :: keyword()) :: any()
  @callback request(req :: request()) :: any()
  @callback download(req :: request, source :: binary()) :: any()
  @callback upload(req :: request, destination :: binary()) :: any()
end
