defmodule Minex.S3.Auth do
  @moduledoc false

  alias Minex.S3.Auth.{Const, Utils}
  alias Minex.HTTP.Request

  @type request :: Request.t()
  @type date :: DateTime.t()

  # Task 1: Create a canonical request
  @spec get_canonical_request(
          req :: request(),
          ignored_headers :: [binary()],
          hashed_payload :: binary()
        ) :: binary()
  def get_canonical_request(req, ignored_headers, hashed_payload) do
    [
      req.method,
      "\n",
      Utils.get_canonical_data(req, :uri),
      "\n",
      Utils.get_canonical_data(req, :query),
      "\n",
      Utils.get_canonical_data(req, :headers, ignored_headers),
      "\n\n",
      Utils.get_signed_headers(req, ignored_headers),
      "\n",
      hashed_payload
    ]
    |> IO.iodata_to_binary()
  end

  # Task 2: Create a String to Sign
  @spec get_string_to_sign_v4(
          canonical_request :: binary(),
          datetime :: date(),
          location :: binary(),
          service_type :: binary()
        ) :: binary()
  def get_string_to_sign_v4(canonical_request, datetime, location, service_type) do
    [
      Const.sign_v4_algorithm(),
      "\n",
      Utils.datetime_string(datetime),
      "\n",
      Utils.get_scope(datetime, location, service_type),
      "\n",
      Utils.hash_sha256(canonical_request)
    ]
    |> IO.iodata_to_binary()
  end

  # Task 3: Get hmac signing key.
  @spec get_signing_key(
          secret_key :: binary(),
          datetime :: date(),
          location :: binary(),
          service_type :: binary()
        ) :: binary()
  def get_signing_key(secret_key, datetime, location, service_type) do
    ["AWS4", secret_key]
    |> Utils.hmac_sha256(Utils.date_string(datetime))
    |> Utils.hmac_sha256(location)
    |> Utils.hmac_sha256(service_type)
    |> Utils.hmac_sha256("aws4_request")
  end

  # Task 4: Calculate signature.
  @spec get_signature(
          signing_key :: binary(),
          string_to_sign :: binary()
        ) :: binary()
  def get_signature(signing_key, string_to_sign) do
    Utils.hmac_sha256(signing_key, string_to_sign)
    |> Utils.bytes_to_hex()
  end

  @spec get_credential(
          access_key :: binary,
          datetime :: date(),
          location :: binary(),
          service_type :: binary()
        ) :: binary()
  def get_credential(access_key, datetime, location, service_type) do
    scope = Utils.get_scope(datetime, location, service_type)
    access_key <> "/" <> scope
  end

  @spec sign_v4(
          req :: request(),
          access_key :: binary(),
          secret_key :: binary(),
          session_token :: binary(),
          location :: binary(),
          service_type :: binary(),
          datetime :: date()
        ) :: request()
  def sign_v4(req, access_key, secret_key, session_token, location, service_type, datetime)
      when access_key != "" or secret_key != "" do

    # Get the hashed payload
    hashed_payload = Utils.get_hashed_payload(req)

    # Pre-process headers
    headers =
      req.headers
      # Remove if these headers exist and set them with the correct values
      |> Utils.remove_headers(["authorization", "host", "x-amz-date"])
      |> Utils.set_headers_host_date(req, datetime)
      # Set session token if available.
      |> Utils.set_session_token(session_token)
      # Add the x-amz-content-sha256 header
      |> Utils.set_hashed_payload(hashed_payload)
      # Check if the aws service is a Security Token Service
      |> Utils.check_service_sts(service_type)
      # Normalize and merge headers
      |> Utils.merge_headers()

    # Insert the headers in the requets
    req = req |> Map.replace!(:headers, headers)

    # Task 1: Get a canonical request
    canonical_request = get_canonical_request(req, Const.v4_ignored_headers(), hashed_payload)

    # Task 2: Get string to sign from canonical request.
    string_to_sign = get_string_to_sign_v4(canonical_request, datetime, location, service_type)

    # Task 3: Get hmac signing key.
    signing_key = get_signing_key(secret_key, datetime, location, service_type)

    # Task 4: Calculate signature.
    signature = get_signature(signing_key, string_to_sign)

    # Get credential string.
    credential = get_credential(access_key, datetime, location, service_type)

    # Get all signed headers.
    signed_headers = Utils.get_signed_headers(req, Const.v4_ignored_headers())

    # If regular request, construct the final authorization header.
    auth =
      [
        Const.sign_v4_algorithm(),
        " ",
        "Credential=",
        credential,
        ",",
        "SignedHeaders=",
        signed_headers,
        ",",
        "Signature=",
        signature
      ]
      |> IO.iodata_to_binary()

    headers = [{"Authorization", auth} | headers]
    struct(req, %{headers: headers})
  end


  # Stream chunk sign

  # Task 1:
  # def build_seed_sign() do

  # end

  # def get_content_length(data_size, signature) do

  # end


  # def build_chunk_string_to_sign(chunk_data, datetime, location, access_key, previous_signature) do

  # end

  # def sign_chunk() do

  # end

  # def build_chunk_signature(chunk_data, datetime, location, previous_signature, secret_key) do

  # end

  # # string(IntHexBase(chunk-size)) + ";chunk-signature=" + signature + \r\n + chunk-data + \r\n
  # def build_chunk_header(chunk_size, signature) do
  #   [
  #     Integer.to_string(chunk_size, 16),
  #     ";chunk-signature=",
  #     signature,
  #     "\r\n"
  #   ]
  #   |> IO.iodata_to_binary()
  # end

  # @spec sign_multiple_chunk_v4(
  #         req :: request(),
  #         access_key :: binary(),
  #         secret_key :: binary(),
  #         session_token :: binary(),
  #         location :: binary(),
  #         service_type :: binary(),
  #         datetime :: date(),
  #         data_size :: number()
  #       ) :: request()
  # def sign_multiple_chunk_v4(req, access_key, secret_key, session_token, location, service_type, datetime, data_size)
  #     when access_key != "" or secret_key != "" do

  #   # Get the hashed payload
  #   hashed_payload = Utils.get_hashed_payload(req)

  #   # Pre-process headers
  #   headers =
  #     req.headers
  #     # Remove if these headers exist and set them with the correct values
  #     |> Utils.remove_headers(["authorization", "host", "x-amz-date"])
  #     |> Utils.set_headers_host_date(req, datetime)
  #     # Set session token if available.
  #     |> Utils.set_session_token(session_token)
  #     # Add the x-amz-content-sha256 header
  #     |> Utils.set_hashed_payload(hashed_payload)
  #     # Check if the aws service is a Security Token Service
  #     |> Utils.check_service_sts(service_type)
  #     # Normalize and merge headers
  #     |> Utils.merge_headers()

  #   # Insert the headers in the requets
  #   req = req |> Map.replace!(:headers, headers)
  # end

end
