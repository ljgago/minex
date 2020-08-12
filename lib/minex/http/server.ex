defmodule Minex.HTTP.Server do
  @moduledoc false

  use GenServer
  require Logger

  defstruct [
    :conn,
    requests: %{}
  ]

  @type req :: Minex.HTTP.Request.t()

  # Client
  #

  def request(req) do
    # owner + message
    {:ok, pid} = GenServer.start_link(__MODULE__, req)
    url = URI.parse(req.url)
    GenServer.call(pid, {:request, req.method, url.path, req.headers, req.body})
    GenServer.stop(pid, :normal, :infinity)
  end

  # Server
  @impl true
  def init(req) do
    url = URI.parse(req.url)

    with {:ok, conn} <- Mint.HTTP.connect(String.to_atom(url.scheme), url.host, url.port) do
      state = %__MODULE__{conn: conn}
      {:ok, state}
    end
  end

  @impl true
  def handle_call({:request, method, path, headers, body}, from, state) do
    case Mint.HTTP.request(state.conn, method, path, headers, body) do
      {:ok, conn, request_ref} ->
        Logger.info(fn -> "the request_ref is: #{inspect(request_ref)}" end)
        state = put_in(state.conn, conn)

        state =
          put_in(state.requests[request_ref], %{from: from, response: %Minex.HTTP.Response{}})

        {:noreply, state}

      {:error, conn, reason} ->
        state = put_in(state.conn, conn)
        Logger.error(fn -> "the request got an error: #{inspect(reason)}" end)
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_info(message, state) do
    case Mint.HTTP.stream(state.conn, message) do
      :unknown ->
        _ = Logger.error(fn -> "Received unknown message: " <> inspect(message) end)
        {:noreply, state}

      {:ok, conn, mint_responses} ->
        _ = Logger.info(fn -> "Received responses: " <> inspect(mint_responses) end)
        state = put_in(state.conn, conn)
        state = Enum.reduce(mint_responses, state, &process_response/2)
        {:noreply, state}

      {:error, conn, error, _mint_responses} ->
        state = put_in(state.conn, conn)
        _ = Logger.error(fn -> "Received error message: " <> inspect(error) end)
        {:noreply, state}
    end
  end

  @impl true
  def terminate(reason, state) do
    Logger.info(fn ->
      "the httpclient is done with reason #{inspect(reason)}, requests done: #{inspect(state)}"
    end)
  end

  defp process_response({:status, request_ref, status}, state) do
    put_in(state.requests[request_ref].response[:status_code], status)
  end

  defp process_response({:headers, request_ref, headers}, state) do
    put_in(state.requests[request_ref].response[:headers], headers)
  end

  defp process_response({:data, request_ref, new_data}, state) do
    update_in(state.requests[request_ref].response[:data], fn data -> (data || "") <> new_data end)
  end

  defp process_response({:done, request_ref}, state) do
    Logger.info("It's done! state: #{inspect(state)}")
    {%{response: response, from: from}, state} = pop_in(state.requests[request_ref])
    GenServer.reply(from, {:ok, response})
    {:ok, _} = Mint.HTTP.close(state.conn)
    state
  end
end

# defmodule MyApp.HttpClient do
#   use GenServer
#
#   require Logger
#
#   defstruct [:conn, requests: %{}] # %PizzaDeliveryWeb.HttpClient{conn: nil, requests: %{}}
#
#   # Interface
#
#   def start_link({scheme, host, port}) do
#     GenServer.start_link(__MODULE__, {scheme, host, port}) #owner + message
#   end
#
#   def request(pid, method, path, headers, body) do
#     GenServer.call(pid, {:request, method, path, headers, body})
#   end
#
#   def close_connection(pid) do
#     GenServer.cast(pid, :close_connection)
#   end
#
#   def connection_open?(pid) do
#     GenServer.call(pid, :connection_open)
#   end
#
#   def stop(pid, reason \\ :normal, timeout \\ :infinity) do
#     GenServer.stop(pid, reason, timeout)
#   end
#
#   ## Callbacks
#
#
#   @impl true
#   def handle_call({:request, method, path, headers, body}, from, state) do
#     case Mint.HTTP.request(state.conn, method, path, headers, body) do
#       {:ok, conn, request_ref} ->
#         Logger.info(fn -> "the request_ref is: #{inspect(request_ref)}" end)
#         state = put_in(state.conn, conn)
#         state = put_in(state.requests[request_ref], %{from: from, response: %{}})
#               {:noreply, state}
#
#       {:error, conn, reason} ->
#         state = put_in(state.conn, conn)
#         Logger.error(fn -> "the request got an error: #{inspect(reason)}" end)
#         {:reply, {:error, reason}, state}
#     end
#   end
#
#   def handle_call(:connection_open, _from, state) do
#     {:reply, Mint.HTTP.open?(state.conn), state}
#   end
#
#    @impl true
#   def handle_cast(:close_connection, state) do
#     {:ok, conn} = Mint.HTTP.close(state.conn)
#     {:noreply, put_in(state.conn, conn)}
#   end
#
#   @impl true
#   def handle_info(message, state) do
#       Logger.info("the website responded: #{inspect(message)}")
#     case Mint.HTTP.stream(state.conn, message) do
#       :unknown ->
#         _ = Logger.error(fn -> "Received unknown message: " <> inspect(message) end)
#         {:noreply, state}
#
#       {:ok, conn, responses} ->
#         _ = Logger.info(fn -> "Received responses: " <> inspect(responses) end)
#         state = put_in(state.conn, conn)
#         state = Enum.reduce(responses, state, &process_response/2)
#         {:noreply, state}
#
#       {:error, conn, error, _responses} ->
#         state = put_in(state.conn, conn)
#         _ = Logger.error(fn -> "Received error message: " <> inspect(error) end)
#         {:noreply, state}
#     end
#   end
#
#   @impl true
#   def terminate(reason, state) do
#     Logger.info(fn -> "the httpclient is done with reason #{inspect(reason)}, requests done: #{inspect(state)}" end)
#   end
#
#   defp process_response({:status, request_ref, status}, state) do
#     put_in(state.requests[request_ref].response[:status], status)
#   end
#
#   defp process_response({:headers, request_ref, headers}, state) do
#     put_in(state.requests[request_ref].response[:headers], headers)
#   end
#
#   defp process_response({:data, request_ref, new_data}, state) do
#     update_in(state.requests[request_ref].response[:data], fn data -> (data || "") <> new_data end)
#   end
#
#   defp process_response({:done, request_ref}, state) do
#     Logger.info("It's done! state: #{inspect(state)}")
#     {%{response: response, from: from}, state} = pop_in(state.requests[request_ref])
#     GenServer.reply(from, {:ok, response})
#     state
#   end
#
# end
