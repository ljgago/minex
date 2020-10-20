defmodule Minex.HTTP do
  @moduledoc false
  @type request :: Minex.S3.Request.t()

  alias Minex.HTTP
  @spec request(req :: request()) :: {:ok, any()} | {:error, any()}
  def request(req) do
    {:ok, pid} = HTTP.Client.start_link()
    response = HTTP.Client.request_process(pid, req)
    HTTP.Client.stop_process(pid)
    response
  end

  def download() do
    
  end

  def upload() do
    
  end

end

# Q3AM3UQ867SPQQA43P2F
# zuf+tfteSlswRu7BJ86wekitnifILbZam1KYY3TG
