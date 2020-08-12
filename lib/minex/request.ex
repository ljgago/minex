defmodule Minex.Request do
  @moduledoc false

  require Logger
  alias Minex.{Auth, HTTPClient, Payload}

  defstruct [
    :scheme,
    :host,
    :port,
    :method,
    :path,
    :query,
    :headers,
    :body
  ]

  @type t :: %__MODULE__{}
  @type req :: t()

  @atom_methods [
    :get,
    :post,
    :put,
    :patch,
    :delete,
    :head,
    :options
  ]
  @methods [
    "GET",
    "POST",
    "PUT",
    "PATCH",
    "DELETE",
    "HEAD",
    "OPTIONS"
  ]
  @method_to_atom Enum.zip(@methods, @atom_methods) |> Enum.into(%{})

  @type conn :: Minex.Conn.t()
  @type request :: Minex.Request.t()
  @type request_option ::
          {:method, binary()}
          | {:path, binary()}
          | {:query, list()}
          | {:headers, list()}
          | {:body, iodata()}
  @type request_options :: [request_option()]

  # maxPartsCount - 10000
  # minPartSize - 128MiB
  # maxMultipartPutObjectSize - 5TiB
  # https://docs.aws.amazon.com/AmazonS3/latest/dev/qfacts.html

  @spec make_request(conn :: conn(), options :: request_options()) :: request()
  def make_request(conn, options) do
    body = Keyword.get(options, :body, "")
    headers = Keyword.get(options, :headers, [])
    headers = payload_header(body, headers)

    %Minex.Request{
      scheme: conn.secure,
      host: conn.host,
      port: conn.port,
      method: Keyword.get(options, :method),
      path: Keyword.get(options, :path, "/"),
      query: Keyword.get(options, :query, []),
      headers: headers,
      body: body
    }
    |> Auth.sign_v4(conn.access_key, conn.secret_key, "", conn.region, "s3")
  end

  @spec do_request(req :: request()) :: {:ok, any()} | {:error, any()}
  def do_request(req) do
    Logger.debug(
      "Minex Request: METHOD: #{inspect(req.method)} - URL: #{inspect(get_url(req, :url))} - HEADERS: #{
        inspect(req.headers)
      } - BODY: #{inspect(req.body)}"
    )

    HTTPClient.request(
      method: build_method(req.method),
      url: get_url(req, :url),
      headers: req.headers,
      body: req.body
    )
  end

  @spec do_request!(req :: request()) :: any()
  def do_request!(req) do
    {:ok, resp} =
      HTTPClient.request(
        method: build_method(req.method),
        url: get_url(req, :url),
        headers: req.headers,
        body: req.body
      )

    resp
  end

  @spec payload_header(body :: binary(), headers :: list()) :: list()
  defp payload_header(body, headers) do
    payload = Payload.calc_hash(body)

    List.insert_at(headers, -1, {
      "X-Amz-Content-Sha256",
      payload
    })
  end

  defp build_method(method) when is_atom(method), do: method
  defp build_method(method) when method in @methods, do: @method_to_atom[method]

  @spec get_url(req :: req(), atom()) :: binary()
  def get_url(req, :authority) do
    if req.port do
      "#{req.host}:#{req.port}"
    else
      req.host
    end
  end

  def get_url(req, :host) do
    req.host
  end

  def get_url(req, :url) do
    if req.port do
      "#{req.scheme}://#{req.host}:#{req.port}#{req.path || "/"}"
    else
      "#{req.scheme}://#{req.host}#{req.path || "/"}"
    end
  end
end
