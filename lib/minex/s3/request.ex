defmodule Minex.S3.Request do
  @moduledoc false

  require Logger
  alias Minex.S3.Utils

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
#
#  @type conn :: Minex.Conn.t()
#  @type request :: Minex.Request.t()
#  @type request_option ::
#          {:method, binary()}
#          | {:path, binary()}
#          | {:query, list()}
#          | {:headers, list()}
#          | {:body, iodata() | fun()}
#  @type request_options :: [request_option()]
#
#  # maxPartsCount - 10000
#  # minPartSize - 128MiB
#  # maxMultipartPutObjectSize - 5TiB
#  # https://docs.aws.amazon.com/AmazonS3/latest/dev/qfacts.html
#
#  @spec make_request(conn :: conn(), options :: request_options()) :: request()
#  def make_request(conn, options) do
#    body = Keyword.get(options, :body, "")
#    headers = Keyword.get(options, :headers, [])
#    headers = payload_header(body, headers)
#
#    %Minex.Request{
#      scheme: conn.secure,
#      host: conn.host,
#      port: conn.port,
#      method: Keyword.get(options, :method),
#      path: Keyword.get(options, :path, "/"),
#      query: Keyword.get(options, :query, []),
#      headers: headers,
#      body: body
#    }
#    |> Auth.sign_v4(conn.access_key, conn.secret_key, "", conn.region, "s3")
#  end
#
#  @spec do_request(req :: request()) :: {:ok, any()} | {:error, any()}
#  def do_request(req) do
#    Logger.debug(
#      "Minex Request: METHOD: #{inspect(req.method)
#        } - URL: #{inspect(get_url_to_string(req))
#        } - HEADERS: #{inspect(req.headers)
#        } - QUERY: #{inspect(req.query)
#        } - BODY: #{inspect(req.body)
#      }"
#    )
#
#    HTTP.request(req)
#
#    #HTTPClient.request(
#    #  method: build_method(req.method),
#    #  url: get_url_to_string(req),
#    #  headers: req.headers,
#    #  query: req.query,
#    #  body: req.body,
#    #  #opts: opts
#    #)
#  end
#
#  @spec do_request!(req :: request()) :: any()
#  def do_request!(req) do
#    {:ok, resp} = do_request(req)
#
#    resp
#  end
#
#  def do_request_to_file do
#    
#  end
#
#  def do_stream_request(req) do
#    
#  end
#
  @spec payload_header(body :: binary(), headers :: list()) :: list()
  def payload_header(body, headers) do
    #body = ""
    payload = Utils.calc_hash(body)

    List.insert_at(headers, -1, {
      "X-Amz-Content-Sha256",
      payload
    })
  end

  defp build_method(method) when is_atom(method), do: method
  defp build_method(method) when method in @methods, do: @method_to_atom[method]

  def get_authority(%{host: host, port: port}) when port == 80 or port == 443, do: host
  def get_authority(%{host: host, port: port}), do: "#{host}:#{port}"

  def get_host(%{host: host}), do: host

  def get_query(%{query: query}) when is_nil(query) or query == [], do: nil
  def get_query(%{query: query}), do: URI.encode_query(query)

  def get_port(%{port: port, scheme: :http}) when is_nil(port), do: 80
  def get_port(%{port: port, scheme: :https}) when is_nil(port), do: 443
  def get_port(%{port: port}), do: port

  def get_url_to_string(req) do
    %URI{
      host: req.host,
      path: req.path,
      port: get_port(req),
      # query: get_query(req),
      scheme: Atom.to_string(req.scheme)
    }
    |> URI.to_string()
    |> URI.encode()
  end
end
