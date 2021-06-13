defmodule Minex.Conn do
  @moduledoc false

  defstruct host: "localhost",
            port: 9000,
            access_key: "minioadmin",
            secret_key: "minioadmin",
            secure: :http,
            region: "us-east-1"

  @type t :: %__MODULE__{
          host: String.t(),
          port: pos_integer(),
          access_key: String.t(),
          secret_key: String.t(),
          secure: :https | :http,
          region: String.t()
        }
end
