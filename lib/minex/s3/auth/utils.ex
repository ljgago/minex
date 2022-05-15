defmodule Minex.S3.Auth.Utils do
  @moduledoc false

  alias Minex.S3.Auth.Const
  alias Minex.HTTP.Request

  @spec hash_sha256(data :: String.t()) :: String.t()
  def hash_sha256(data) do
    :sha256
    |> :crypto.hash(data)
    |> bytes_to_hex
  end

  def hmac_sha256(key, data) do
    :crypto.mac(:hmac, :sha256, key, data)
  end

  def bytes_to_hex(bytes) do
    bytes
    |> Base.encode16(case: :lower)
  end

  def datetime_from_header(headers) do
    header = Enum.find(headers, fn {key, _} -> String.downcase(key) == "x-amz-date" end)
    case header do
      nil -> DateTime.utc_now()
      {_, value} ->
        {:ok, {yy, mm, dd, h, m, s, us}, _} = Calendar.ISO.parse_utc_datetime(value, :basic)
        {:ok, datetime, _} = Calendar.ISO.datetime_to_string(yy, mm, dd, h, m, s, us, "Etc/UTC", "UTC", 0, 0)
                             |> DateTime.from_iso8601()
        datetime
    end
  end

  @spec date_string(datetime :: DateTime.t()) :: String.t()
  def date_string(datetime) do
    datetime
    |> DateTime.to_date()
    |> Date.to_iso8601(:basic)
  end

  @spec datetime_string(datetime :: DateTime.t()) :: String.t()
  def datetime_string(datetime) do
    datetime
    |> DateTime.truncate(:second)
    |> DateTime.to_iso8601(:basic)
  end

  def remove_headers(data, list_to_remove) do
    data
    |> Enum.reject(fn {key, _value} ->
      String.downcase(key) in list_to_remove
    end)
  end

  def unique_headers(headers) do
    headers
    |> Map.new(fn {key, value} -> {String.downcase(key), value} end)
    |> Enum.map(fn {key, value} -> {key, value} end)
  end

  def merge_headers(headers) do
    headers
    |> Enum.reduce(Map.new(), fn {key, value}, acc ->
      case Map.get(acc, String.downcase(key)) do
        nil -> Map.merge(acc, %{String.downcase(key) => value})
        _ -> Map.put(acc, String.downcase(key), "#{Map.get(acc, String.downcase(key))}, #{value}")
      end
    end)
    |> Enum.map(fn {key, value} -> {key, value} end)
  end

  def get_signed_headers(req, ignore_headers) do
    req.headers
    |> remove_headers(ignore_headers)
    |> List.insert_at(0, {"host", ""})
    |> Map.new(fn {key, value} -> {String.downcase(key), value} end)
    |> Enum.map_join(";", fn {key, _value} -> key end)
  end

  def get_canonical_data(req, :uri) do
    req.path
    |> URI.encode()
  end

  def get_canonical_data(req, :query) do
    req.query
    |> Map.new(fn {key, value} -> {key, value} end)
    |> URI.encode_query()
  end

  def get_canonical_data(req, :headers, ignore_headers) do
    req.headers
    |> remove_headers(ignore_headers)
    |> Map.new(fn {key, value} -> {String.downcase(key), value} end)
    |> encode_header
  end

  @spec get_canonical_uri(binary()) :: binary()
  def get_canonical_uri(uri) do
    uri
    |> URI.encode()
  end

  @spec get_canonical_query(keyword()) :: binary()
  def get_canonical_query(query) do
    query
    |> Map.new(fn {key, value} -> {key, value} end)
    |> URI.encode_query()
  end

  def get_canonical_headers(req, ignore_headers) do
    req.headers
    |> remove_headers(ignore_headers)
    |> Map.new(fn {key, value} -> {String.downcase(key), value} end)
    |> encode_header
  end

  # @spec get_canonical_headers([{String.t, String.t}]) :: String.t
  # def get_canonical_headers(data) do
  #  data
  #  |> encode_header
  # end

  defp encode_header(headers) do
    headers
    |> Enum.map_join("\n", &encode_kv_pair/1)
  end

  defp encode_kv_pair({key, _}) when is_list(key) do
    raise ArgumentError, "encode_header/1 keys cannot be lists, got: #{inspect(key)}"
  end

  defp encode_kv_pair({_, value}) when is_list(value) do
    raise ArgumentError, "encode_header/1 values cannot be lists, got: #{inspect(value)}"
  end

  defp encode_kv_pair({key, value}) do
    String.downcase(Kernel.to_string(key)) <> ":" <> String.trim(Kernel.to_string(value))
  end

  @spec get_signed_header_key([{String.t(), String.t()}]) :: String.t()
  def get_signed_header_key(headers) do
    headers
    |> Enum.map_join(";", fn {key, _value} -> key end)
  end

  def get_scope(datetime, location, service_type) do
    [
      date_string(datetime),
      "/",
      location,
      "/",
      service_type,
      "/",
      "aws4_request"
    ]
    |> IO.iodata_to_binary()
  end


  def get_hashed_payload(req) do
    hashed_payload =
      req.headers
      |> Enum.find_value("", fn {key, value} ->
        if String.downcase(key) == "x-amz-content-sha256" do
          value
        end
      end)

    case hashed_payload do
      "" -> Const.unsigned_payload()
      _ -> hashed_payload
    end
  end

  def set_headers_host_date(headers, req, datetime) do
    [
      {"host", Request.get_authority(req)},
      {"x-amz-date", datetime_string(datetime)}
      | headers
    ]
  end

  def set_session_token(headers, session_token) do
    case session_token do
      "" -> headers
      _ -> [{"x-amz-security-token", session_token} | headers]
    end
  end

  def set_hashed_payload(headers, hashed_payload) do
    if Enum.find(headers, fn {key, _} -> String.downcase(key) == "x-amz-content-sha256" end) != nil do
      headers
    else
      # Get the payload from header
      [{"x-amz-content-sha256", hashed_payload} | headers]
    end
  end

  def check_service_sts(headers, service_type) do
    if service_type == Const.service_type_sts() do
      # Content sha256 header is not sent with the request
      # but it is expected to have sha256 of payload for signature
      # in STS service type request.
      remove_headers(headers, ["x-amz-content-sha256"])
    else
      headers
    end
  end

  # def pre_sign_header(req) do
  #   datetime = Utils.datetime_from_header(req.headers)

  #   # Remove `authorization`, `host` and `x-amz-date`
  #   headers = Utils.remove_headers(req.headers, ["authorization", "host", "x-amz-date"])

  #   headers = [
  #     {"host", Request.get_authority(req)},
  #     {"x-amz-date", Utils.datetime_string(datetime)}
  #     | headers
  #   ]

  #   # Set session token if available.
  #   headers =
  #     case session_token do
  #       "" -> headers
  #       _ -> [{"x-amz-security-token", session_token} | headers]
  #     end

  #   # Get the payload from header
  #   hashed_payload = get_hashed_payload(req)

  #   # Add the x-amz-content-sha256 header
  #   headers =
  #     if Enum.find(headers, fn {key, _} -> String.downcase(key) == "x-amz-content-sha256" end) !=
  #          nil do
  #       headers
  #     else
  #       [{"x-amz-content-sha256", hashed_payload} | headers]
  #     end

  #   headers =
  #     if service_type == Const.service_type_sts() do
  #       # Content sha256 header is not sent with the request
  #       # but it is expected to have sha256 of payload for signature
  #       # in STS service type request.
  #       Utils.remove_headers(headers, ["x-amz-content-sha256"])
  #     else
  #       headers
  #     end

  #   # Noromalize and merge headers
  #   headers = Utils.merge_headers(headers)

  # end

end
