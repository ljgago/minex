defmodule Minex.HTTP.Adapter.Finch do
  @moduledoc false

  @behaviour Minex.HTTP.Adapter

  @impl true
  def start_link(opts) do
    Finch.start_link(opts)
  end

  @impl true
  def init(config) do
    Finch.init(config)
  end

  @impl true
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

  @impl true
  def request_filestream(req, file_path, file_opts) do
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

    file = File.open!(file_path, file_opts)

    acc = {nil, [], []}

    fun = fn
      {:status, value}, {_, headers, body} ->
        {value, headers, body}

      {:headers, value}, {status, headers, body} ->
        {status, headers ++ value, body}

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
         body: "File download finished."
       }}
    end
  end

  # @impl true
  # def upload(req, file_path, file_opts, :normal) do
  #   finch_req = %Finch.Request{
  #     scheme: req.scheme,
  #     host: req.host,
  #     port: req.port,
  #     method: req.method,
  #     path: req.path,
  #     headers: req.headers,
  #     body: req.body,
  #     query: URI.encode_query(req.query)
  #   }

  #   # {:ok, data_size, finch_req}
  # end

  # @impl true
  # def upload(req, file_path, file_opts, :multipart) do
  #   finch_req = %Finch.Request{
  #     scheme: req.scheme,
  #     host: req.host,
  #     port: req.port,
  #     method: req.method,
  #     path: req.path,
  #     headers: req.headers,
  #     body: req.body,
  #     query: URI.encode_query(req.query)
  #   }

  #   File.stream!(file_path, [], file_opts.extra[:part_size] || @min_part_size)
  #   |> Task.async_stream(HTTP, :upload, [],
  #     max_concurrency: Keyword.get(file_opts.extra, :max_concurrency, 4),
  #     timeout: Keyword.get(file_opts.extra, :timeout, 30_000)
  #   )

  #   Enum.chunk()
  #   |> Task.async_stream(chunk, [Map.delete(op, :src), config],
  #     max_concurrency: Keyword.get(op.opts, :max_concurrency, 4),
  #     timeout: Keyword.get(op.opts, :timeout, 30_000)
  #   )

  #   # |> Enum.each(fn chunk ->

  #   Stream.with_index(1)
  #   # {:ok, data_size, finch_req}
  # end
end
