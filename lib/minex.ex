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

  alias Minex.{Options, Parsers, Request}

  @type conn :: Minex.Conn.t()
  @type request :: Minex.Request.t()
  @type options :: Minex.Options.t()
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
    %Minex.Conn{}
  end

  @spec new(map()) :: conn()
  def new(data) do
    data
    |> Enum.reduce(%Minex.Conn{}, fn t, acc ->
      Map.replace!(acc, elem(t, 0), elem(t, 1))
    end)
  end

  # Bucket operations

  @spec list_buckets(conn()) :: {:ok, list()} | {:error, any()}
  def list_buckets(conn) do
    conn
    |> Request.make_request(method: "GET")
    |> Request.do_request()
    |> Parsers.parse_list_bucket()
  end

  @spec list_buckets!(conn()) :: any()
  def list_buckets!(conn) do
    {:ok, data} = list_buckets(conn)
    data
  end

  @spec make_bucket(conn(), binary(), options()) :: {:ok} | {:error, any()}
  def make_bucket(conn, bucket_name, opts \\ %Options{}) do
    conn
    |> Request.make_request(
      method: "PUT",
      path: "/" <> bucket_name,
      query: opts.query,
      headers: opts.headers
    )
    |> Request.do_request()
    |> Parsers.parse_make_bucket()
  end

  @spec remove_bucket(conn(), binary()) :: {:ok} | {:error, any()}
  def remove_bucket(conn, bucket_name) do
    conn
    |> Request.make_request(method: "DELETE", path: "/" <> bucket_name)
    |> Request.do_request()
    |> Parsers.parse_remove_bucket()
  end

  @spec bucket_exist?(conn(), binary()) :: boolean()
  def bucket_exist?(conn, bucket_name) do
    conn
    |> Request.make_request(method: "HEAD", path: "/" <> bucket_name)
    |> Request.do_request()
    |> Parsers.parse_bucket_exist()
  end

  @spec list_objects(conn(), binary(), binary(), boolean(), options()) ::
          {:ok, list()} | {:error, any()}
  def list_objects(conn, bucket_name, prefix, recursive \\ false, opts \\ %Options{}) do
    conn
    |> Request.make_request(
      method: "GET",
      path: "/#{bucket_name}/#{prefix}",
      query: opts.query,
      headers: opts.headers
    )
    |> Request.do_request()
    |> Parsers.parse_list_objects()

    {:ok, []}
  end

  def list_incomplete_uploads(conn, bucket_name, prefix, resursive \\ false) do
    {:ok}
  end
end
