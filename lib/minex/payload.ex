defmodule Minex.Payload do
  @moduledoc false

  def calc_hash(data) do
    :crypto.hash(:sha256, data)
    |> Base.encode16()
    |> String.downcase()
  end

  @spec calc_hash_file(
          path :: binary(),
          chunk_size :: pos_integer() | :line
        ) :: binary()
  def calc_hash_file(path, chunk_size)
      when is_binary(path) and (is_integer(chunk_size) or is_atom(chunk_size)) do
    File.stream!(path, [], chunk_size)
    |> Enum.reduce(:crypto.hash_init(:sha256), &:crypto.hash_update(&2, &1))
    |> :crypto.hash_final()
    |> Base.encode16()
    |> String.downcase()
  end

  # Benchee.run(%{
  #   "chunk_128KB" => fn ->
  #     Minex.Payload.hash_stream("/home/soporte/Videos/Sintel.2010.1080p.mkv", 128 * 1024)
  #   end,
  #   "chunk_64KB" => fn ->
  #     Minex.Payload.hash_stream("/home/soporte/Videos/Sintel.2010.1080p.mkv", 64 * 1024)
  #   end,
  #   "chunk_256KB" => fn ->
  #     Minex.Payload.hash_stream("/home/soporte/Videos/Sintel.2010.1080p.mkv", 256 * 1024)
  #   end,
  #   "chunk_512KB" => fn ->
  #     Minex.Payload.hash_stream("/home/soporte/Videos/Sintel.2010.1080p.mkv", 512 * 1024)
  #   end
  #   },
  #   time: 10,
  #   memory_time: 2
  # )
end
