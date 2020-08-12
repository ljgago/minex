defmodule Minex.AuthTest do
  use ExUnit.Case
  doctest Minex.Auth

  alias Minex.{Auth, Auth.Const}

  # GET https://iam.amazonaws.com/?Action=ListUsers&Version=2010-05-08 HTTP/1.1
  # Host: iam.amazonaws.com
  # Content-Type: application/x-www-form-urlencoded; charset=utf-8
  # X-Amz-Date: 20150830T123600Z

  test "Auth sign_v4: Create a canonical request" do
    req = %Minex.Request{
      scheme: :https,
      host: "iam.amazonaws.com",
      method: "GET",
      path: "/",
      query: [{"Action", "ListUsers"}, {"Version", "2010-05-08"}],
      headers: [
        {"Content-Type", "application/x-www-form-urlencoded; charset=utf-8"},
        # ignored header
        {"User-Agent", "foo"},
        # ignored header
        {"Authorization", "foo"},
        {"X-Amz-Date", "20150830T123600Z"},
        {"Host", "iam.amazonaws.com"}
      ],
      body: ""
    }

    ignored_headers = Const.v4_ignored_headers()
    hashed_payload = Const.unsigned_payload()

    canonical_request = Auth.get_canonical_request(req, ignored_headers, hashed_payload)

    canonical_request_expected =
      [
        "GET",
        "\n",
        "/",
        "\n",
        "Action=ListUsers&Version=2010-05-08",
        "\n",
        "content-type:application/x-www-form-urlencoded; charset=utf-8",
        "\n",
        "host:iam.amazonaws.com",
        "\n",
        "x-amz-date:20150830T123600Z",
        "\n",
        "\n",
        "content-type;host;x-amz-date",
        "\n",
        "UNSIGNED-PAYLOAD"
      ]
      |> IO.iodata_to_binary()

    assert canonical_request == canonical_request_expected
  end

  test "Auth sign_v4: Get string to sign" do
    canonical_request =
      [
        "GET",
        "\n",
        "/",
        "\n",
        "Action=ListUsers&Version=2010-05-08",
        "\n",
        "content-type:application/x-www-form-urlencoded; charset=utf-8",
        "\n",
        "host:iam.amazonaws.com",
        "\n",
        "x-amz-date:20150830T123600Z",
        "\n",
        "\n",
        "content-type;host;x-amz-date",
        "\n",
        "UNSIGNED-PAYLOAD"
      ]
      |> IO.iodata_to_binary()

    {:ok, datetime, _} = DateTime.from_iso8601("2015-08-30T12:36:00Z")
    location = "us-east-1"
    service_type = "s3"

    string_to_sign =
      Auth.get_string_to_sign_v4(canonical_request, datetime, location, service_type)

    string_to_sign_expected =
      [
        "AWS4-HMAC-SHA256",
        "\n",
        "20150830T123600Z",
        "\n",
        "20150830/us-east-1/s3/aws4_request",
        "\n",
        "2714b15fec5795e21b0fa0c48f6944f639224b42fd8e71d16f57ed58265f9c7d"
      ]
      |> IO.iodata_to_binary()

    assert string_to_sign == string_to_sign_expected
  end

  test "Auth sign_v4: Get signing key" do
    secret_key = "wJalrXUtnFEMI/K7MDENG+bPxRfiCYEXAMPLEKEY"
    {:ok, datetime, _} = DateTime.from_iso8601("2015-08-30T12:36:00Z")
    location = "us-east-1"
    service_type = "iam"

    signing_key = Auth.get_signing_key(secret_key, datetime, location, service_type)

    signing_key_expected =
      "į\xB1\xCCWq\xD8qv:9>D\xB7\x03W\eU\xCC(BM\x1A^\x86\xDAn\xD3\xC1T\xA4\xB9"

    assert signing_key == signing_key_expected
  end

  test "Auth sign_v4: Calculate signature" do
    string_to_sign =
      [
        "AWS4-HMAC-SHA256",
        "\n",
        "20150830T123600Z",
        "\n",
        "20150830/us-east-1/iam/aws4_request",
        "\n",
        "f536975d06c0309214f805bb90ccff089219ecd68b2577efef23edd43b7e1a59"
      ]
      |> IO.iodata_to_binary()

    signing_key = "į\xB1\xCCWq\xD8qv:9>D\xB7\x03W\eU\xCC(BM\x1A^\x86\xDAn\xD3\xC1T\xA4\xB9"

    signature = Auth.get_signature(signing_key, string_to_sign)
    signature_expected = "5d672d79c15b13162d9279b0855cfba6789a8edb4c82c400e06b5924a6f2b5d7"

    assert signature == signature_expected
  end
end
