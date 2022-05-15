defmodule Minex.HTTP do
  @moduledoc false

  use Supervisor

  @impl true
  defdelegate init(config), to: Minex.HTTP.Adapter.Finch
  defdelegate start_link(opts), to: Minex.HTTP.Adapter.Finch
  defdelegate request(req), to: Minex.HTTP.Adapter.Finch
  defdelegate request_filestream(req, file_path, file_opts), to: Minex.HTTP.Adapter.Finch
end
