defmodule Minex.S3.Auth.Const do
  @moduledoc false

  def sign_v4_algorithm do
    "AWS4-HMAC-SHA256"
  end

  # unsigned_payload - value to be set to X-Amz-Content-Sha256 header when
  def unsigned_payload do
    "UNSIGNED-PAYLOAD"
  end

  # http://docs.aws.amazon.com/AmazonS3/latest/API/sigv4-streaming.html#example-signature-calculations-streaming
  def streaming_sign_algorithm do
    "STREAMING-AWS4-HMAC-SHA256-PAYLOAD"
  end

  def streaming_payload_hdr do
    "AWS4-HMAC-SHA256-PAYLOAD"
  end

  def empty_sha256 do
    "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
  end

  def service_type_s3 do
    "s3"
  end

  def service_type_sts do
    "sts"
  end

  def v4_ignored_headers do
    [
      "authorization",
      "user-agent"
    ]
  end

  def payload_chunk_size do
    64 * 1024
  end

  def chunk_sig_const_len do
    # ";chunk-signature="
    17
  end

  def signature_str_len do
    # e.g. "f2ca1bb6c7e907d06dafe4687e579fce76b37e4e93b7605022da52e6ccc26fd2"
    64
  end

  def crlf_len do
    # CRLF
    2
  end
end
