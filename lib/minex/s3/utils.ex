defmodule Minex.S3.Utils do
  @moduledoc false

  @type conn :: Minex.Conn.t()
  @type req :: Minex.Request.t()

  @valid_bucket_name ~r/^[A-Za-z0-9][A-Za-z0-9\.\-\_\:]{1,61}[A-Za-z0-9]$/
  @valid_bucket_name_strict ~r/^[a-z0-9][a-z0-9\.\-]{1,61}[a-z0-9]$/
  @ip_address ~r/^(\d+\.){3}\d+$/

  @spec get_url(
          conn :: conn(),
          path :: binary(),
          query :: binary()
        ) :: binary()
  def get_url(conn, path, query) do
    secure = Atom.to_string(conn.secure)
    host = conn.host
    port = Integer.to_string(conn.port)

    case query do
      "" -> "#{secure}://#{host}:#{port}#{path}"
      _ -> "#{secure}://#{host}:#{port}#{path}?#{query}"
    end
  end

  def check_bucket_name(bucket_name, strict \\ false) do
    cond do
      String.trim(bucket_name) == "" ->
        {:error, "Bucket name cannot be empty"}

      String.length(bucket_name) < 3 ->
        {:error, "Bucket name cannot be shorter than 3 characters"}

      String.length(bucket_name) > 63 ->
        {:error, "Bucket name cannot be longer than 63 characters"}

      String.match?(bucket_name, @ip_address) ->
        {:error, "Bucket name cannot be an ip address"}

      String.contains?(bucket_name, "..") ||
        String.contains?(bucket_name, ".-") ||
          String.contains?(bucket_name, "-.") ->
        {:error, "Bucket name contains invalid characters"}

      String.match?(bucket_name, @valid_bucket_name_strict) == false and strict ->
        {:error, "Bucket name contains invalid characters"}

      String.match?(bucket_name, @valid_bucket_name) == false ->
        {:error, "Bucket name contains invalid characters"}

      true ->
        {:ok}
    end
  end

  def from_amazon?(host) do
    [
      # amazonS3HostHyphen - regular expression used to determine if an arg is s3 host in hyphenated style.
      ~r/^s3-(.*?).amazonaws.com$/,
      # amazonS3HostDualStack - regular expression used to determine if an arg is s3 host dualstack.
      ~r/^s3.dualstack.(.*?).amazonaws.com$/,
      # amazonS3HostDot - regular expression used to determine if an arg is s3 host in . style.
      ~r/^s3.(.*?).amazonaws.com$/,
      # amazonS3ChinaHost - regular expression used to determine if the arg is s3 china host.
      ~r/^s3.(cn.*?).amazonaws.com.cn$/,
      # Regular expression used to determine if the arg is elb host.
      ~r/elb(.*?).amazonaws.com$/,
      # Regular expression used to determine if the arg is elb host in china.
      ~r/elb(.*?).amazonaws.com.cn$/
    ]
    |> Enum.any?(fn value -> String.match?(host, value) end)
  end

  def amazon_region?(region) do
    [
      "us-east-1",
      "us-east-2",
      "us-west-1",
      "us-west-2",
      "ca-central-1",
      "eu-west-1",
      "eu-west-2",
      "eu-west-3",
      "eu-central-1",
      "eu-north-1",
      "ap-east-1",
      "ap-south-1",
      "ap-southeast-1",
      "ap-southeast-2",
      "ap-northeast-1",
      "ap-northeast-2",
      "ap-northeast-3",
      "me-south-1",
      "sa-east-1",
      "us-gov-west-1",
      "us-gov-east-1",
      "cn-north-1",
      "cn-northwest-1"
    ]
    |> Enum.any?(&(&1 == region))
  end


  def calc_hash(data) do
    :crypto.hash(:sha256, data)
    |> Base.encode16()
    |> String.downcase()
  end

  @spec calc_hash_file(
          path :: binary(),
          chunk_size :: pos_integer() | :line
        ) :: binary()
  def calc_hash_file(path, chunk_size)
      when is_binary(path) and (is_integer(chunk_size) or is_atom(chunk_size)) do
    File.stream!(path, [], chunk_size)
    |> Enum.reduce(:crypto.hash_init(:sha256), &:crypto.hash_update(&2, &1))
    |> :crypto.hash_final()
    |> Base.encode16()
    |> String.downcase()
  end

  # defp ip_addr_match?(addr) do
  #   try do
  #     {:ok, _} = :inet.parse_address(String.to_charlist(addr))
  #     true
  #   catch
  #     false
  #   end
  # end

  # Task 1: Create a canonical request for Signature Version 4
  #   1. Start with the HTTP request method (GET, PUT, POST, etc.), followed by
  #   a newline character.
  #
  #   2. Add the canonical URI parameter, followed by a newline character. The
  #   canonical URI is the URI-encoded version of the absolute path component
  #   of the URI, which is everything in the URI from the HTTP host to the
  #   question mark character ("?") that begins the query string parameters
  #   (if any).
  #   Normalize URI paths according to RFC 3986. Remove redundant and relative
  #   path components. Each path segment must be URI-encoded twice (except for
  #   Amazon S3 which only gets URI-encoded once).
  #
  #   3. Add the canonical query string, followed by a newline character. If
  #   therequest does not include a query string, use an empty string
  #   (essentially, a blank line). The example request has the following query
  #   string.
  #
  #   4. Add the canonical headers, followed by a newline character. The
  #   canonical headers consist of a list of all the HTTP headers that you are
  #   including with the signed request.
  #   For HTTP/1.1 requests, you must include the host header at a minimum.
  #   Standard headers like content-type are optional.For HTTP/2 requests, you
  #   must include the :authority header instead of the host header. Different
  #   services might require other headers.
  #
  #   5. Add the signed headers, followed by a newline character. This value is
  #   the list of headers that you included in the canonical headers. By adding
  #   this list of headers, you tell AWS which headers in the request are part
  #   of the signing process and which ones AWS can ignore (for example, any
  #   additional headers added by a proxy) for purposes of validating the
  #   request.
  #   For HTTP/1.1 requests, the host header must be included as a signed
  #   header. For HTTP/2 requests that include the :authority header instead of
  #   the host header, you must include the :authority header as a signed
  #   header. If you include a date or x-amz-date header, you must also include
  #   that header in the list of signed headers.
  #   To create the signed headers list, convert all header names to lowercase,
  #   sort them by character code, and use a semicolon to separate the header
  #   names. The following pseudocode describes how to construct a list of
  #   signed headers. Lowercase represents a function that converts all
  #   characters to lowercase.
  #
end
