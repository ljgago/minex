defmodule Minex do
  @moduledoc """
  Minex is a s3 client compatible for [MinIO](https://min.io) server.

  ## Quickstart

      conn = Minex.new()
      {:ok, data} = Minex.list_buckets(conn)
      #=> {:ok,
      #   [
      #     %{"creation_date" => "2020-08-06T00:49:04.609Z", "name" => "movies"},
      #     %{"creation_date" => "2020-08-06T05:58:31.432Z", "name" => "pics"}
      #   ]}
  """
  alias Minex.Conn
  alias Minex.S3
  alias Minex.S3.Options

  @type conn :: Conn.t()
  @type options :: Options.t()
  @doc """
  Create a new connection with default options.

  Default `conn` coptions:

  * `:host` - ("localhost") hostname or ip server.
  * `:port` - (9000) port of the server.
  * `:access_key` - ("minioadmin") access key authentication.
  * `:secret_key` - ("minioadmin") secret key authentication.
  * `:secure` - (:http) use `:http` for unsafe or `:https` for safe connection.
  * `:region` - ("us-east-1") the location region.
  """
  @spec new :: conn()
  def new do
    %Conn{}
  end

  @spec new(map()) :: conn()
  def new(data) do
    struct(Conn, data)
    # data
    # |> Enum.reduce(%Conn{}, fn t, acc ->
    #   Map.replace!(acc, elem(t, 0), elem(t, 1))
    # end)
  end

  # Bucket operations

  @doc """
  List all buckets

    conn = Minex.new()
    Minex.list_buckets(conn)
  """
  @spec list_buckets(conn :: conn()) :: {:ok, list()} | {:error, any()}
  def list_buckets(conn) do
    conn
    |> S3.make_request(method: "GET")
    |> S3.do_request()
    |> S3.parse_list_bucket()
  end

  @spec list_buckets!(conn :: conn()) :: any()
  def list_buckets!(conn) do
    {:ok, data} = list_buckets(conn)
    data
  end

  @spec make_bucket(
          conn :: conn(),
          bucket_name :: binary(),
          opts :: options()
        ) :: {:ok} | {:error, any()}
  def make_bucket(conn, bucket_name, opts \\ %Options{}) do
    conn
    |> S3.make_request(
      method: "PUT",
      path: ["/", bucket_name] |> IO.iodata_to_binary(),
      query: opts.query,
      headers: opts.headers
    )
    |> S3.do_request()
    |> S3.parse_make_bucket()
  end

  @spec remove_bucket(
          conn :: conn(),
          bucket_name :: binary()
        ) :: {:ok} | {:error, any()}
  def remove_bucket(conn, bucket_name) do
    conn
    |> S3.make_request(method: "DELETE", path: ["/", bucket_name] |> IO.iodata_to_binary())
    |> S3.do_request()
    |> S3.parse_remove_bucket()
  end

  @spec bucket_exist?(
          conn :: conn(),
          bucket_name :: binary()
        ) :: boolean()
  def bucket_exist?(conn, bucket_name) do
    conn
    |> S3.make_request(method: "HEAD", path: ["/", bucket_name] |> IO.iodata_to_binary())
    |> S3.do_request()
    |> S3.parse_bucket_exist()
  end

  @spec list_objects(
          conn :: conn(),
          bucket_name :: binary(),
          prefix :: binary(),
          recursive :: boolean(),
          opts :: options()
        ) :: {:ok, list()} | {:error, any()}
  def list_objects(conn, bucket_name, prefix \\ "", recursive \\ true, opts \\ %Options{}) do
    opts = Options.options_list_objects(opts, prefix, recursive)

    conn
    |> S3.make_request(
      method: "GET",
      path: ["/", bucket_name] |> IO.iodata_to_binary(),
      query: opts.query,
      headers: opts.headers
    )
    |> S3.do_request()
    |> S3.parse_list_objects()
  end

  @spec list_objects_v2(
          conn :: conn(),
          bucket_name :: binary(),
          prefix :: binary(),
          recursive :: boolean(),
          opts :: options()
        ) :: {:ok, list()} | {:error, any()}
  def list_objects_v2(conn, bucket_name, prefix \\ "", recursive \\ true, opts \\ %Options{}) do
    opts = %Options{
      query: [{"list-type", "2"} | opts.query],
      headers: opts.headers,
      extra: opts.extra
    }
    list_objects(conn, bucket_name, prefix, recursive, opts)
  end

  # def list_incomplete_uploads(conn, bucket_name, prefix, resursive \\ false) do
  #   {:ok}
  # end

  # Object operations

  @spec get_object(
    conn :: conn(),
    bucket_name :: binary(),
    object_name :: binary(),
    opts :: options()
  ) :: {:ok, binary()} | {:error, any()}
  def get_object(conn, bucket_name, object_name, opts \\ %Options{}) do
    conn
    |> S3.make_request(
      method: "GET",
      path: ["/", bucket_name, "/", object_name] |> IO.iodata_to_binary(),
      query: opts.query,
      headers: opts.headers
    )
    |> S3.do_request()
    |> S3.parse_get_object()
  end

  @spec fget_object(
    conn :: conn(),
    bucket_name :: binary(),
    object_name :: binary(),
    file_path :: binary(),
    opts :: options()
  ) :: {:ok, binary()} | {:error, any()}
  def fget_object(conn, bucket_name, object_name, file_path, opts \\ %Options{}) do
    conn
    |> S3.make_request(
      method: "GET",
      path: ["/", bucket_name, "/", object_name] |> IO.iodata_to_binary(),
      query: opts.query,
      headers: opts.headers,
      body: ""
    )
    |> S3.do_request(file_path, :download)
  end

  @spec put_object(
    conn :: conn(),
    bucket_name :: binary(),
    object_name :: binary(),
    object :: binary(),
    opts :: options()
  ) :: {:ok, any()} | {:error, any()}
  def put_object(conn, bucket_name, object_name, object, opts \\ %Options{}) do
    conn
    |> S3.make_request(
      method: "PUT",
      path: ["/", bucket_name, "/", object_name] |> IO.iodata_to_binary(),
      query: opts.query,
      headers: opts.headers,
      body: object
    )
    |> S3.do_request()
  end

  # @spec fput_object(
  #   conn :: conn(),
  #   bucket_name :: binary(),
  #   object_name :: binary(),
  #   file_path :: binary(),
  #   opts :: options()
  # ) :: {:ok, any()} | {:error, any()}
  # def fput_object(conn, bucket_name, object_name, file_path, opts \\ %Options{}) do
  #   # File.stream!(file_path, [], opts.extra[:chunk_size] || 5 * 1024 * 1024)
  #   # |> Enum.each(fn chunk ->
      
  #   # end)
  #   {:ok, ""}
  # end

end
