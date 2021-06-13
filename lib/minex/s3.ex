defmodule Minex.S3 do
  @moduledoc false

  require Logger
  alias Minex.{Conn, HTTP}
  alias Minex.S3.{Auth, Utils, XML}
  
  @type conn :: Conn.t()
  @type request :: HTTP.Request.t()
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
    headers = payload_header(body, headers)

    %HTTP.Request{
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

  @spec do_request(req :: request(), file_path :: binary(), mode :: atom()) :: {:ok, any()} | {:error, any()}
  def do_request(req, file_path \\ "", mode \\ :normal) do
    Logger.debug(
      "Minex Request: METHOD: #{inspect(req.method)
        } - URL: #{inspect(HTTP.Request.get_url_to_string(req))
        } - HEADERS: #{inspect(req.headers)
        } - QUERY: #{inspect(req.query)
        } - BODY: #{inspect(req.body)
      }"
    )

    case mode do
      :normal -> HTTP.request(req)
      :download -> HTTP.download(req, file_path)
      :upload -> HTTP.upload(req, file_path)
      _ -> raise ArgumentError, message: "the atom #{mode} is a invalid mode"
    end

  end

  @spec do_request!(req :: request()) :: any()
  def do_request!(req) do
    {:ok, resp} = do_request(req)

    resp
  end

  # def do_request_to_file do
  # end

  # def do_stream_request(req) do
  # end

  @spec payload_header(body :: binary(), headers :: list()) :: list()
  def payload_header(body, headers) do
    #body = ""
    payload = Utils.calc_hash(body)

    List.insert_at(headers, -1, {
      "X-Amz-Content-Sha256",
      payload
    })
  end

  def parse_list_bucket({:ok, %{body: data, status: status}}) when status == 200 do
    data =
      XML.to_map(data)
      |> get_in(["list_all_my_buckets_result", "buckets", "bucket"])
      |> normalize()

    {:ok, data}
  end

  def parse_list_bucket({:ok, %{body: data}}), do: common_error(data)
  def parse_list_bucket({:error, error}), do: {:error, error}

  def parse_make_bucket({:ok, %{status: status}}) when status == 200, do: {:ok}
  def parse_make_bucket({:ok, %{body: data}}), do: common_error(data)
  def parse_make_bucket({:error, error}), do: {:error, error}

  def parse_remove_bucket({:ok, %{status: status}}) when status == 204, do: {:ok}
  def parse_remove_bucket({:ok, %{body: data}}), do: common_error(data)
  def parse_remove_bucket({:error, error}), do: {:error, error}

  def parse_bucket_exist({:ok, %{status: status}}) when status == 200, do: true
  def parse_bucket_exist({:ok, _}), do: false
  def parse_bucket_exist({:error, error}), do: {:error, error}

  def parse_list_objects({:ok, %{body: data, status: status}}) when status == 200 do
    data =
      XML.to_map(data)
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

  def parse_list_objects({:ok, %{body: data}}), do: common_error(data)
  def parse_list_objects({:error, error}), do: {:error, error}

  # Object operations

  def parse_get_object({:ok, %{body: data, status: status}}) when status == 200, do:  {:ok, data}
  def parse_get_object({:ok, %{body: data}}), do: common_error(data)
  def parse_get_object({:error, error}), do: {:error, error}

  # def parse_fget_object({:ok, %{body: data, status: status}}) when status == 200 do
  # end


  defp common_error(data), do: {:error, XML.to_map(data)}

  defp normalize(data) when is_nil(data), do: []
  defp normalize(data) when is_map(data), do: [data]
  defp normalize(data), do: data

end
