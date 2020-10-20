defmodule Minex.S3.XML do
  @moduledoc false

  # From https://github.com/homanchou/elixir-xml-to-map
  # I changed the code for response with tags with underscore notation

  def xml_to_map(xml) do
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

  # defp to_underscore(data) do
  #  Map.new(data, fn {key, value} ->
  #    {Macro.underscore(key), value}
  #  end)
  # end
  # for %{k, v} <- map, into: %{}, do: {replacement_for(k, tuple), v}
end
