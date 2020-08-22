defmodule Minex.Auth do
  @moduledoc false

  alias Minex.Auth.{Const, Utils}

  @type request :: Minex.Request.t()
  @type date :: any()

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
      Utils.get_canonical_uri(req.path),
      "\n",
      Utils.get_canonical_query(req.query),
      "\n",
      Utils.get_canonical_headers(req, ignored_headers),
      "\n",
      "\n",
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

  @spec sign_v4(
          req :: request(),
          access_key :: binary(),
          secret_key :: binary(),
          session_token :: binary(),
          location :: binary(),
          service_type :: binary()
        ) :: request()
  def sign_v4(req, access_key, secret_key, session_token, location, service_type)
      when access_key != "" or secret_key != "" do
    # Initial time
    datetime = DateTime.utc_now()

    # Set the X-Amz-Date
    headers = [
      {"Host", Minex.Request.get_authority(req)},
      {"X-Amz-Date", Utils.datetime_string(datetime)}
      | req.headers
    ]

    # Set session token if available.
    headers =
      case session_token do
        "" -> headers
        _ -> [{"X-Amz-Security-Token", session_token} | headers]
      end

    # Get the payload from header
    hashed_payload = get_hashed_payload(req)

    headers =
      if service_type == Const.service_type_sts() do
        # Content sha256 header is not sent with the request
        # but it is expected to have sha256 of payload for signature
        # in STS service type request.
        Utils.remove_headers(headers, ["x-amz-content-sha256"])
      else
        headers
      end

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
        " Credential=",
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
    req |> Map.replace!(:headers, headers)
  end
end
