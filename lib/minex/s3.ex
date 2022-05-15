defmodule Minex.S3 do
  @moduledoc false

  require Logger

  alias Minex.{Conn, HTTP}
  alias Minex.S3.{Auth, Options, Utils}

  alias Minex.S3.Parsers

  @type conn :: Conn.t()
  @type options :: Options.t()
  @type request :: HTTP.Request.t()
  @type request_option ::
          {:method, binary()}
          | {:path, binary()}
          | {:query, list()}
          | {:headers, list()}
          | {:body, iodata() | fun()}
  @type request_options :: [request_option()]

  # https://docs.aws.amazon.com/AmazonS3/latest/dev/qfacts.html

  # @abs_min_part_size - absolute minimum part size (5 MiB) below which
  # a part in a multipart upload may not be uploaded.
  @abs_min_part_size 1024 * 1024 * 5

  # @min_part_size - minimum part size 128MiB per object after which
  @min_part_size 1024 * 1024 * 128

  # @max_parts_count - maximum number of parts for a single multipart session.
  @max_part_count 10_000

  # @max_part_size - maximum part size 5GiB for a single multipart upload
  # operation.
  @max_part_size 1024 * 1024 * 1024 * 5

  # @max_single_put_object_size - maximum size 5GiB of object per PUT
  # operation.
  # Max size 5GiB
  @max_single_put_object_size 1024 * 1024 * 1024 * 5

  # @max_multipart_put_object_size - maximum size 5TiB of object for
  # Multipart operation.
  # Max size 5TiB
  @max_multipart_put_object_size 1024 * 1024 * 1024 * 1024 * 5

  @spec make_request(conn :: conn(), options :: request_options()) :: request()
  def make_request(conn, options) do
    body = Keyword.get(options, :body, "")

    headers =
      Keyword.get(options, :headers, [])
      |> payload_header(body)

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
    |> Auth.sign_v4(conn.access_key, conn.secret_key, "", conn.region, "s3", DateTime.utc_now())
  end

  @spec payload_header(headers :: list(), body :: binary()) :: list()
  defp payload_header(headers, body) do
    payload = Utils.calc_hash(body)

    List.insert_at(headers, -1, {
      "X-Amz-Content-Sha256",
      payload
    })
  end

  @spec do_request(req :: request()) :: {:ok, any()} | {:error, any()}
  def do_request(req) do
    # Logger.debug("Minex Request: METHOD: #{inspect(req.method)} -
    #   URL: #{inspect(HTTP.Request.get_url_to_string(req))} -
    #   HEADERS: #{inspect(req.headers)} -
    #   QUERY: #{inspect(req.query)} -
    #   BODY: #{inspect(req.body)}")

    HTTP.request(req)
  end

  @spec do_request!(req :: request()) :: any()
  def do_request!(req) do
    {:ok, resp} = do_request(req)

    resp
  end

  #
  # Download functions
  #

  @spec do_download(req :: request(), file_path :: binary()) :: Task.t()
  def do_download(req, file_path) do
    # Logger.debug("Minex Request: METHOD: #{inspect(req.method)} -
    #   URL: #{inspect(HTTP.Request.get_url_to_string(req))} -
    #   HEADERS: #{inspect(req.headers)} -
    #   QUERY: #{inspect(req.query)} - BODY: ...")

    Task.async(HTTP, :request_filestream, [
      req,
      file_path,
      [:write, {:delayed_write, @abs_min_part_size, 5000}]
    ])
  end

  def check_download(task) do
    Task.yield(task, 0)
  end

  #
  # Upload functions
  #

  @spec get_upload_mode(file_path :: binary()) :: :normal | :multipart
  def get_upload_mode(file_path) do
    with %{size: data_size} <- File.stat!(file_path) do
      if data_size <= @min_part_size, do: :normal, else: :multipart
    end
  end

  @spec do_normal_upload(
          conn :: conn(),
          bucket :: binary(),
          object :: binary(),
          file_path :: binary(),
          opts :: options()
        ) :: any()
  def do_normal_upload(conn, bucket, object, file_path, opts) do
    {:ok, data} = File.read(file_path)

    conn
    |> make_request(
      method: "PUT",
      path: build_path(bucket, object),
      query: opts.query,
      headers: opts.headers,
      body: data
    )
    |> do_request()
  end

  #
  # Multipart Upload
  #

  @spec do_multipart_upload(
          conn :: conn(),
          bucket :: binary(),
          object :: binary(),
          file_path :: binary(),
          opts :: options()
        ) :: any()
  def do_multipart_upload(conn, bucket, object, file_path, opts) do
    %{size: data_size} = File.stat!(file_path)

    part_size = Keyword.get(opts.extra, :part_size, @min_part_size)

    # Check the the max part count and get the part size
    with {:ok} <- check_part_size(data_size, part_size),
         # 1. Create multipart upload
         {:ok, %{"upload_id" => upload_id}} <- create_multipart_upload(conn, bucket, object, opts) do
      File.stream!(file_path, [], opts.extra[:part_size] || @min_part_size)
      |> Stream.with_index(1)
      |> Task.async_stream(
        fn {chunk, part_number} ->
          # 2. Upload part
          upload_part({chunk, part_number}, conn, bucket, object, upload_id, opts)
        end,
        max_concurrency: Keyword.get(opts.extra, :max_concurrency, 4),
        timeout: Keyword.get(opts.extra, :timeout, 30_000)
      )
      |> Enum.to_list()
      # 4. Complete multipart upload
      |> complete_multipart_upload(conn, bucket, object, upload_id)
    else
      {:error, error} -> {:error, error}
    end
  end

  defp check_part_size(data_size, part_size) do
    part_count = div(data_size, part_size)

    cond do
      data_size > @max_multipart_put_object_size ->
        {:error, "The data size is greater than #{@max_multipart_put_object_size} bytes"}

      part_size < @abs_min_part_size ->
        {:error, "The part size is less than #{@abs_min_part_size} bytes"}

      part_size > @max_single_put_object_size ->
        {:error, "The part size is greater than #{@max_single_put_object_size} bytes"}

      part_count > @max_part_count ->
        {:error, "The part count is greater than #{@max_part_count}"}
    end

    {:ok}
  end

  # 1. Create multipart upload
  # https://docs.aws.amazon.com/AmazonS3/latest/API/API_CreateMultipartUpload.html
  defp create_multipart_upload(conn, bucket, object, opts) do
    conn
    |> make_request(
      method: "POST",
      path: build_path(bucket, object),
      query: [{"uploads", ""} | opts.query],
      headers: opts.headers,
      body: ""
    )
    |> do_request()
    |> Parsers.parse_create_multipart_upload()
  end

  # 2. Upload part
  # https://docs.aws.amazon.com/AmazonS3/latest/API/API_UploadPart.html
  defp upload_part({chunk, part_number}, conn, bucket, object, upload_id, opts) do
    conn
    |> make_request(
      method: "PUT",
      path: build_path(bucket, object),
      query: [{"uploadId", upload_id}, {"partNumber", part_number} | opts.query],
      headers: opts.headers,
      body: chunk
    )
    |> do_request()
    |> Parsers.parse_upload_part(part_number)
  end

  # 3. Upload part copy
  # https://docs.aws.amazon.com/AmazonS3/latest/API/API_UploadPartCopy.html
  def upload_part_copy(conn, dest_bucket, dest_object, src_bucket, src_object, opts) do
  end

  # 4. Complete multipart upload
  # https://docs.aws.amazon.com/AmazonS3/latest/API/API_CompleteMultipartUpload.html
  defp complete_multipart_upload(parts, conn, bucket, object, upload_id) do
    parts_xml =
      parts
      |> Enum.map(fn {:ok, {part_number, etag}} ->
        [
          "<Part>",
          "<PartNumber>",
          Integer.to_string(part_number),
          "</PartNumber>",
          "<ETag>",
          etag,
          "</ETag>",
          "</Part>"
        ]
      end)

    body =
      ["<CompleteMultipartUpload>", parts_xml, "</CompleteMultipartUpload>"]
      |> IO.iodata_to_binary()

    conn
    |> make_request(
      method: "POST",
      path: build_path(bucket, object),
      query: [{"uploadId", upload_id}],
      headers: [],
      body: body
    )
    |> do_request()
    |> Parsers.parse_complete_multipart_upload()
  end

  def list_parts(conn, bucket, object, upload_id, opts) do
    conn
    |> make_request(
      method: "DELETE",
      path: build_path(bucket, object),
      query: [{"uploadId", upload_id} | opts.query],
      headers: opts.headers,
      body: ""
    )
    |> do_request()
  end

  def abort_multipart_upload() do
  end

  #
  # Aux functions
  #

  def content_length_header(headers, body) do
    List.insert_at(headers, -1, {
      "Content-Length",
      String.length(body)
    })
  end

  defp build_path(bucket),
    do: ["/", bucket] |> IO.iodata_to_binary()

  defp build_path(bucket, object),
    do: ["/", bucket, "/", object] |> IO.iodata_to_binary()
end
