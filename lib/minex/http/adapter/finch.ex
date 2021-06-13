defmodule Minex.HTTP.Adapter.Finch do
  @behaviour Minex.HTTP.Adapter

  @impl Minex.HTTP.Adapter
  def start_link(opts) do
    Finch.start_link(opts)
  end

  def init(config) do
    Finch.init(config)
  end

  @impl Minex.HTTP.Adapter
  def request(req) do
    %Finch.Request{
      scheme: req.scheme,
      host: req.host,
      port: req.port,
      method: req.method,
      path: req.path,
      headers: req.headers,
      body: req.body,
      query: URI.encode_query(req.query)
    }
    |> Finch.request(Minex.Pool)
  end

  @impl Minex.HTTP.Adapter
  def download(req, file_path) do
    finch_req = %Finch.Request{
      scheme: req.scheme,
      host: req.host,
      port: req.port,
      method: req.method,
      path: req.path,
      headers: req.headers,
      body: req.body,
      query: URI.encode_query(req.query)
    }

    file = File.open!(file_path, [:write, {:delayed_write, 5*1024*1024, 5000}])

    acc = {nil, [], []}

    fun = fn
      {:status, value}, {_, headers, body} -> {value, headers, body}
      {:headers, value}, {status, headers, body} -> {status, headers ++ value, body}
      {:data, value}, {status, headers, body} -> 
        IO.binwrite(file, value)
        {status, headers, body}
    end

    with {:ok, {status, headers, _}} <- Finch.stream(finch_req, Minex.Pool, acc, fun, []) do
      File.close(file)
      {:ok,
       %{
         status: status,
         headers: headers,
         body: ""
       }}
    end
  end

  @impl Minex.HTTP.Adapter
  def upload(_req, _destination) do
  end

end
