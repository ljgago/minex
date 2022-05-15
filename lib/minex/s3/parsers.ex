defmodule Minex.S3.Parsers do
  @moduledoc false

  # From https://github.com/homanchou/elixir-xml-to-map
  # I changed the code for response with tags with underscore notation

  defp to_map(xml) do
    naive_map(xml)
  end

  defp naive_map(xml) do
    xml = String.replace(xml, ~r/(\sxmlns="\S+")|(xmlns:ns2="\S+")/, "")
    {:ok, tree, _tail} = :erlsom.simple_form(xml)
    parse(tree)
  end

  defp parse([{tag, attributes, content}]) do
    parse({tag, attributes, content})
  end

  defp parse([value]) do
    to_string(value) |> String.trim()
  end

  defp parse({tag, [], content}) do
    parsed_content = parse(content)
    %{Macro.underscore(to_string(tag)) => parsed_content}
  end

  defp parse({tag, attributes, content}) do
    attributes_map =
      Enum.reduce(attributes, %{}, fn {attribute_name, attribute_value}, acc ->
        Map.put(acc, "-#{attribute_name}", to_string(attribute_value))
      end)

    parsed_content = parse(content)
    joined_content = %{"#content" => parsed_content} |> Map.merge(attributes_map)

    %{Macro.underscore(to_string(tag)) => joined_content}
  end

  defp parse(list) when is_list(list) do
    parsed_list = Enum.map(list, &{Macro.underscore(to_string(elem(&1, 0))), parse(&1)})

    Enum.reduce(parsed_list, %{}, fn {k, v}, acc ->
      case Map.get(acc, k) do
        nil ->
          for({key, value} <- v, into: %{}, do: {key, value})
          |> Map.merge(acc)

        [h | t] ->
          Map.put(acc, k, [h | t] ++ [v[k]])

        prev ->
          Map.put(acc, k, [prev] ++ [v[k]])
      end
    end)
  end

  # XML parser

  def parse_list_bucket({:ok, %{body: data, status: status}}) when status == 200 do
    data =
      to_map(data)
      |> get_in(["list_all_my_buckets_result", "buckets", "bucket"])
      |> normalize()

    {:ok, data}
  end

  def parse_list_bucket({:ok, %{body: data}}), do: common_error(data)
  def parse_list_bucket({:error, error}), do: {:error, error}

  def parse_make_bucket({:ok, %{status: status}}) when status == 200, do: {:ok}
  def parse_make_bucket({:ok, %{body: data}}), do: common_error(data)
  def parse_make_bucket({:error, error}), do: {:error, error}

  def parse_remove_bucket({:ok, %{status: status}}) when status == 204, do: {:ok}
  def parse_remove_bucket({:ok, %{body: data}}), do: common_error(data)
  def parse_remove_bucket({:error, error}), do: {:error, error}

  def parse_bucket_exist({:ok, %{status: status}}) when status == 200, do: true
  def parse_bucket_exist({:ok, _}), do: false
  def parse_bucket_exist({:error, error}), do: {:error, error}

  def parse_list_objects({:ok, %{body: data, status: status}}) when status == 200 do
    data =
      to_map(data)
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

  def parse_list_objects({:ok, %{body: data}}), do: common_error(data)
  def parse_list_objects({:error, error}), do: {:error, error}

  # Object operations

  def parse_get_object({:ok, %{body: data, status: status}}) when status == 200, do: {:ok, data}
  def parse_get_object({:ok, %{body: data}}), do: common_error(data)
  def parse_get_object({:error, error}), do: {:error, error}

  # Multipart parsers

  def parse_create_multipart_upload({:ok, %{body: data, status: status}}) when status == 200 do
    data =
      to_map(data)
      |> get_in(["initiate_multipart_upload_result"])

    # Response:
    #   %{
    #     "bucket" => bucket,
    #     "key" => key,
    #     "upload_id" => upload_id
    #   }

    {:ok, data}
  end

  def parse_upload_part({:ok, %{headers: headers, status: status}}, part_number)
      when status == 200 do
    {_, etag} =
      Enum.find(headers, fn {k, _v} ->
        String.downcase(k) == "etag"
      end)

    {part_number, etag}
  end

  def parse_complete_multipart_upload({:ok, %{body: data, status: status}}) when status == 200 do
    data =
      to_map(data)
      |> get_in(["complete_multipart_upload_result"])

    # Response:
    #   %{
    #     "location" => location,
    #     "bucket" => bucket,
    #     "key" => key,
    #     "e_tag" => e_tag
    #   }

    {:ok, data}
  end

  def parse_complete_multipart_upload({:ok, %{body: data}}), do: common_error(data)
  def parse_complete_multipart_upload({:error, error}), do: {:error, error}

  defp common_error(data), do: {:error, to_map(data)}

  defp normalize(data) when is_nil(data), do: []
  defp normalize(data) when is_map(data), do: [data]
  defp normalize(data), do: data

  # defp to_underscore(data) do
  #  Map.new(data, fn {key, value} ->
  #    {Macro.underscore(key), value}
  #  end)
  # end
  # for %{k, v} <- map, into: %{}, do: {replacement_for(k, tuple), v}
end
