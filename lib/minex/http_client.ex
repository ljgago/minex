defmodule Minex.HTTPClient do
  @moduledoc false
  use Tesla, only: [:request]
  adapter(Tesla.Adapter.Mint)
end
