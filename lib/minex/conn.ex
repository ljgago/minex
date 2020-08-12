defmodule Minex.Conn do
  @moduledoc false

  defstruct host: "localhost",
            port: 9000,
            access_key: "minioadmin",
            secret_key: "minioadmin",
            secure: :http,
            region: "us-east-1"

  # auto_discover_region: true,
  # service: "s3",
  @type t :: %__MODULE__{
          host: String.t(),
          port: pos_integer(),
          access_key: String.t(),
          secret_key: String.t(),
          secure: :https | :http,
          region: String.t()
          # auto_discover_region: true | false,
          # service: String.t(),
        }
end
