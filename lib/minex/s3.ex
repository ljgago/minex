defmodule Minex.S3 do
  @moduledoc false

  require Logger
  alias Minex.S3.{Auth, Conn, Request, XML}
  alias Minex.HTTP
  
  @type conn :: Conn.t()
  @type request :: Request.t()
  @type request_option ::
          {:method, binary()}
          | {:path, binary()}
          | {:query, list()}
          | {:headers, list()}
          | {:body, iodata() | fun()}
  @type request_options :: [request_option()]

  # maxPartsCount - 10000
  # minPartSize - 128MiB
  # maxMultipartPutObjectSize - 5TiB
  # https://docs.aws.amazon.com/AmazonS3/latest/dev/qfacts.html

  @spec make_request(conn :: conn(), options :: request_options()) :: request()
  def make_request(conn, options) do
    body = Keyword.get(options, :body, "")
    headers = Keyword.get(options, :headers, [])
    headers = Request.payload_header(body, headers)

    %Request{
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
      "Minex Request: METHOD: #{inspect(req.method)
        } - URL: #{inspect(Request.get_url_to_string(req))
        } - HEADERS: #{inspect(req.headers)
        } - QUERY: #{inspect(req.query)
        } - BODY: #{inspect(req.body)
      }"
    )

    HTTP.request(req)

    #HTTPClient.request(
    #  method: build_method(req.method),
    #  url: get_url_to_string(req),
    #  headers: req.headers,
    #  query: req.query,
    #  body: req.body,
    #  #opts: opts
    #)
  end

  @spec do_request!(req :: request()) :: any()
  def do_request!(req) do
    {:ok, resp} = do_request(req)

    resp
  end

  def do_request_to_file do
    
  end

  def do_stream_request(req) do
    
  end

  def parse_list_bucket({:ok, %{data: data, status: status}}) when status == 200 do
    data =
      XML.xml_to_map(data)
      |> get_in(["list_all_my_buckets_result", "buckets", "bucket"])
      |> normalize()

    {:ok, data}
  end

  def parse_list_bucket({:ok, %{data: data}}), do: common_error(data)
  def parse_list_bucket({:error, error}), do: {:error, error}

  def parse_make_bucket({:ok, %{status: status}}) when status == 200, do: {:ok}
  def parse_make_bucket({:ok, %{data: data}}), do: common_error(data)
  def parse_make_bucket({:error, error}), do: {:error, error}

  def parse_remove_bucket({:ok, %{status: status}}) when status == 204, do: {:ok}
  def parse_remove_bucket({:ok, %{data: data}}), do: common_error(data)
  def parse_remove_bucket({:error, error}), do: {:error, error}

  def parse_bucket_exist({:ok, %{status: status}}) when status == 200, do: true
  def parse_bucket_exist({:ok, _}), do: false
  def parse_bucket_exist({:error, error}), do: {:error, error}

  def parse_list_objects({:ok, %{data: data, status: status}}) when status == 200 do
    data =
      XML.xml_to_map(data)
      |> get_in(["list_bucket_result", "contents"])
      |> normalize()
      |> Enum.map(fn %{
                       "e_tag" => e_tag,
                       "key" => key,
                       "last_modified" => last_modified,
                       "size" => size
                     } ->
        %{
          "e_tag" => e_tag,
          "key" => key,
          "last_modified" => last_modified,
          "size" => size
        }
      end)

    {:ok, data}
  end

  def parse_list_objects({:ok, %{data: data}}), do: common_error(data)
  def parse_list_objects({:error, error}), do: {:error, error}

  # Object operations

  def parse_get_object({:ok, %{data: data, status: status}}) when status == 200, do:  {:ok, data}
  def parse_get_object({:ok, %{data: data}}), do: common_error(data)
  def parse_get_object({:error, error}), do: {:error, error}

  def parse_fget_object({:ok, %{data: data, status: status}}) when status == 200 do
    
  end


  defp common_error(data), do: {:error, XML.xml_to_map(data)}

  defp normalize(data) when is_nil(data), do: []
  defp normalize(data) when is_map(data), do: [data]
  defp normalize(data), do: data

end
