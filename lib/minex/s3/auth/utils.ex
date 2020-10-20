defmodule Minex.S3.Auth.Utils do
  @moduledoc false

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

  def get_signed_headers(req, ignore_headers) do
    req.headers
    |> remove_headers(ignore_headers)
    |> List.insert_at(0, {"host", ""})
    |> Map.new(fn {key, value} -> {String.downcase(key), value} end)
    |> Enum.map_join(";", fn {key, _value} -> key end)
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

  # @spec get_canonical_headers([{String.t, String.t}]) :: String.t
  # def get_canonical_headers(data) do
  #  data
  #  |> encode_header
  # end

  def get_canonical_headers(req, ignore_headers) do
    req.headers
    |> remove_headers(ignore_headers)
    |> Map.new(fn {key, value} -> {String.downcase(key), value} end)
    |> encode_header
  end

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
end
