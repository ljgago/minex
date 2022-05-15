defmodule MinexTest do
  use ExUnit.Case

  doctest Minex

  setup do
    bypass = Bypass.open()
    {:ok, bypass: bypass}
  end

  # test "Create a new clean connection setting" do
  #   conn = Minex.new()
  #   assert %Minex.Conn{} == conn
  # end

  # test "Create a new custom connection setting" do
  #   conn = Minex.new(%{host: "127.0.0.1", port: 3000, secret_key: "my_secret"})
  #   assert conn == %Minex.Conn{
  #     host: "127.0.0.1",
  #     port: 3000,
  #     access_key: "minioadmin",
  #     secret_key: "my_secret",
  #     secure: :http,
  #     region: "us-east-1"
  #   }
  # end

  # test "List bukets", %{bypass: bypass} do
  #   Bypass.expect(bypass, fn http_conn ->
  #     Plug.Conn.resp(http_conn, 200, "")
  #   end)

  # end
end
