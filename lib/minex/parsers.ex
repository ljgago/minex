defmodule Minex.Parsers do
  @moduledoc false

  alias Minex.XML

  def parse_list_bucket({:ok, %{body: body, status: status}}) when status == 200 do
    data =
      XML.xml_to_map(body)
      |> get_in(["list_all_my_buckets_result", "buckets", "bucket"])
      |> normalize()

    {:ok, data}
  end

  def parse_list_bucket({:ok, %{body: body}}), do: common_error(body)

  def parse_make_bucket({:ok, %{status: status}}) when status == 200, do: {:ok}
  def parse_make_bucket({:ok, %{body: body}}), do: common_error(body)

  def parse_remove_bucket({:ok, %{status: status}}) when status == 204, do: {:ok}
  def parse_remove_bucket({:ok, %{body: body}}), do: common_error(body)

  def parse_bucket_exist({:ok, %{status: status}}) when status == 200, do: true
  def parse_bucket_exist({:ok, _}), do: false

  def parse_list_objects({:ok, %{body: body, status: status}}) when status == 200 do
    data =
      XML.xml_to_map(body)
      |> get_in(["list_all_my_buckets_result"])
      |> normalize()

    {:ok, data}
  end

  def parse_list_objects({:ok, %{body: body}}), do: common_error(body)

  defp common_error(data), do: {:error, XML.xml_to_map(data)}

  defp normalize(data) when is_nil(data), do: []
  defp normalize(data) when is_map(data), do: [data]
  defp normalize(data), do: data

  # def parse_list_bucket({:ok, resp}) do
  #  case resp.status do
  #    200 ->
  #      data = get_in(data, ["list_all_my_buckets_result", "buckets", "bucket"])
  #      {:ok, normalize(data)}
  #    _ ->
  #      {:error, data}
  #  end
  # end

  # def parse_make_bucket({:ok, %{body: body, status: status}}) do
  #  case resp.status do
  #    200 -> {:ok}
  #    _ -> {:error, XML.xml_to_map(resp.body)}
  #  end
  # end

  # def parse_remove_bucket({:ok, resp}) do
  #  case resp.status do
  #    204 -> {:ok}
  #    _ -> {:error, XML.xml_to_map(resp.body)}
  #  end
  # end

  # def parse_bucket_exist({:ok, resp}) do
  #  case resp.status do
  #    200 -> true
  #    _ -> false
  #  end
  # end

  # def parse_list_objects({:ok, resp}) do
  #  data = XML.xml_to_map(resp.body)
  #  case resp.status do
  #    200 ->
  #      data = get_in(data, ["list_all_my_buckets_result"])
  #      {:ok, normalize(data)}
  #    _ -> {:error, data}
  #  end
  # end
end
