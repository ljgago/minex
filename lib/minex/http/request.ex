defmodule Minex.HTTP.Request do
  @moduledoc false

  require Logger

  defstruct [
    :scheme,
    :host,
    :port,
    :method,
    :path,
    :query,
    :headers,
    :body
  ]

  @type t :: %__MODULE__{}
  @type req :: t()

  @atom_methods [
    :get,
    :post,
    :put,
    :patch,
    :delete,
    :head,
    :options
  ]
  @methods [
    "GET",
    "POST",
    "PUT",
    "PATCH",
    "DELETE",
    "HEAD",
    "OPTIONS"
  ]
  # @method_to_atom Enum.zip(@methods, @atom_methods) |> Enum.into(%{})
  # defp build_method(method) when is_atom(method), do: method
  # defp build_method(method) when method in @methods, do: @method_to_atom[method]

  @atom_to_method Enum.zip(@atom_methods, @methods) |> Enum.into(%{})

  defp build_method(method) when is_binary(method), do: method
  defp build_method(method) when method in @atom_methods, do: @atom_to_method[method]

  def get_authority(%{host: host, port: port}) when port == 80 or port == 443 or port == nil, do: host
  def get_authority(%{host: host, port: port}), do: "#{host}:#{port}"

  def get_host(%{host: host}), do: host

  def get_query(%{query: query}) when is_nil(query) or query == [], do: nil
  def get_query(%{query: query}), do: URI.encode_query(query)

  def get_port(%{port: port, scheme: :http}) when is_nil(port), do: 80
  def get_port(%{port: port, scheme: :https}) when is_nil(port), do: 443
  def get_port(%{port: port}), do: port

  def get_url_to_string(req) do
    %URI{
      host: req.host,
      path: req.path,
      port: get_port(req),
      # query: get_query(req),
      scheme: Atom.to_string(req.scheme)
    }
    |> URI.to_string()
    |> URI.encode()
  end
end
