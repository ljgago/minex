defmodule Minex.AuthTest do
  use ExUnit.Case
  # doctest Minex.Auth

  alias Minex.{S3.Auth, HTTP}

  # GET https://iam.amazonaws.com/?Action=ListUsers&Version=2010-05-08 HTTP/1.1
  # Host: iam.amazonaws.com
  # Content-Type: application/x-www-form-urlencoded; charset=utf-8
  # X-Amz-Date: 20150830T123600Z

  @req %HTTP.Request{
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

  @canonical_request [
                       "GET", "\n", "/", "\n",
                       "Action=ListUsers&Version=2010-05-08", "\n",
                       "content-type:application/x-www-form-urlencoded; charset=utf-8", "\n",
                       "host:iam.amazonaws.com", "\n",
                       "x-amz-date:20150830T123600Z", "\n", "\n",
                       "content-type;host;x-amz-date", "\n",
                       "UNSIGNED-PAYLOAD"
                     ]
                     |> IO.iodata_to_binary()

  @string_to_sign [
                    "AWS4-HMAC-SHA256", "\n",
                    "20150830T123600Z", "\n",
                    "20150830/us-east-1/iam/aws4_request", "\n",
                    "2714b15fec5795e21b0fa0c48f6944f639224b42fd8e71d16f57ed58265f9c7d"
                  ]
                  |> IO.iodata_to_binary()

  @access_key "aws_s3_EXAMPLEKEY"
  @secret_key "wJalrXUtnFEMI/K7MDENG+bPxRfiCYEXAMPLEKEY"

  @signing_key "į\xB1\xCCWq\xD8qv:9>D\xB7\x03W\eU\xCC(BM\x1A^\x86\xDAn\xD3\xC1T\xA4\xB9"

  @signature "86116edbb7e0e8c675dc9cfa9fcfcd0115a98ee9cc1196e4623cd2673a806766"

  @sign_v4_request %HTTP.Request{
    scheme: :https,
    host: "iam.amazonaws.com",
    method: "GET",
    path: "/",
    query: [{"Action", "ListUsers"}, {"Version", "2010-05-08"}],
    headers: [
      {"Authorization",
       "AWS4-HMAC-SHA256 Credential=aws_s3_EXAMPLEKEY/20150830/us-east-1/iam/aws4_request,SignedHeaders=content-type;host;x-amz-content-sha256;x-amz-date,Signature=a7bda0351ada18d765b8ebf910139388d682d69f995cca15f7c87676f1bc9d0a"},
      {"content-type", "application/x-www-form-urlencoded; charset=utf-8"},
      {"host", "iam.amazonaws.com"},
      {"user-agent", "foo"},
      {"x-amz-content-sha256", "UNSIGNED-PAYLOAD"},
      {"x-amz-date", "20150830T123600Z"}
    ],
    body: ""
  }

  describe "Minex.S3.Auth" do
    test "task #1: create a canonical request" do
      ignored_headers = Auth.Const.v4_ignored_headers()
      hashed_payload = Auth.Const.unsigned_payload()
      canonical_request = Auth.get_canonical_request(@req, ignored_headers, hashed_payload)

      assert canonical_request == @canonical_request
    end

    test "task #2: get string to sign" do
      {:ok, datetime, _} = DateTime.from_iso8601("2015-08-30T12:36:00Z")
      location = "us-east-1"
      service_type = "iam"

      string_to_sign =
        Auth.get_string_to_sign_v4(@canonical_request, datetime, location, service_type)

      assert string_to_sign == @string_to_sign
    end

    test "task #3: get signing key" do
      {:ok, datetime, _} = DateTime.from_iso8601("2015-08-30T12:36:00Z")
      location = "us-east-1"
      service_type = "iam"
      signing_key = Auth.get_signing_key(@secret_key, datetime, location, service_type)

      assert signing_key == @signing_key
    end

    test "task #4: calculate signature" do
      signature = Auth.get_signature(@signing_key, @string_to_sign)

      assert signature == @signature
    end

    test "sign_v4" do
      {:ok, datetime, _} = DateTime.from_iso8601("2015-08-30T12:36:00Z")

      sign_v4_request =
        Auth.sign_v4(@req, @access_key, @secret_key, "", "us-east-1", "iam", datetime)
      # IO.inspect(sign_v4_request)

      assert sign_v4_request == @sign_v4_request
    end
  end
end
