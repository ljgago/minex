defmodule Minex.S3.Parsers do
  @moduledoc false

  alias Minex.XML

  def parse_list_bucket({:ok, %{data: data, status: status}}) when status == 200 do
    data =
      XML.xml_to_map(data)
      |> get_in(["list_all_my_buckets_result", "buckets", "bucket"])
      |> normalize()

    {:ok, data}
  end

  def parse_list_bucket({:ok, %{data: data}}), do: common_error(data)
  def parse_list_bucket({:error, error}), do: {:error, error}

  def parse_make_bucket({:ok, %{status: status}}) when status == 200, do: {:ok}
  def parse_make_bucket({:ok, %{data: data}}), do: common_error(data)
  def parse_make_bucket({:error, error}), do: {:error, error}

  def parse_remove_bucket({:ok, %{status: status}}) when status == 204, do: {:ok}
  def parse_remove_bucket({:ok, %{data: data}}), do: common_error(data)
  def parse_remove_bucket({:error, error}), do: {:error, error}

  def parse_bucket_exist({:ok, %{status: status}}) when status == 200, do: true
  def parse_bucket_exist({:ok, _}), do: false
  def parse_bucket_exist({:error, error}), do: {:error, error}

  def parse_list_objects({:ok, %{data: data, status: status}}) when status == 200 do
    data =
      XML.xml_to_map(data)
      |> get_in(["list_bucket_result", "contents"])
      |> normalize()
      |> Enum.map(fn %{
                       "e_tag" => e_tag,
                       "key" => key,
                       "last_modified" => last_modified,
                       "size" => size
                     } ->
        %{
          "e_tag" => e_tag,
          "key" => key,
          "last_modified" => last_modified,
          "size" => size
        }
      end)

    {:ok, data}
  end

  def parse_list_objects({:ok, %{data: data}}), do: common_error(data)
  def parse_list_objects({:error, error}), do: {:error, error}

  # Object operations

  def parse_get_object({:ok, %{data: data, status: status}}) when status == 200, do:  {:ok, data}
  def parse_get_object({:ok, %{data: data}}), do: common_error(data)
  def parse_get_object({:error, error}), do: {:error, error}

  def parse_fget_object({:ok, %{data: data, status: status}}) when status == 200 do
    
  end


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

  # def parse_make_bucket({:ok, %{data: data, status: status}}) do
  #  case resp.status do
  #    200 -> {:ok}
  #    _ -> {:error, XML.xml_to_map(resp.data)}
  #  end
  # end

  # def parse_remove_bucket({:ok, resp}) do
  #  case resp.status do
  #    204 -> {:ok}
  #    _ -> {:error, XML.xml_to_map(resp.data)}
  #  end
  # end

  # def parse_bucket_exist({:ok, resp}) do
  #  case resp.status do
  #    200 -> true
  #    _ -> false
  #  end
  # end

  # def parse_list_objects({:ok, resp}) do
  #  data = XML.xml_to_map(resp.data)
  #  case resp.status do
  #    200 ->
  #      data = get_in(data, ["list_all_my_buckets_result"])
  #      {:ok, normalize(data)}
  #    _ -> {:error, data}
  #  end
  # end
end
