defmodule Minex.HTTP.Client do
  @moduledoc false

  use GenServer
  require Logger

  defstruct [:conn, requests: %{}]

  @type t :: %__MODULE__{}
  @type request :: Minex.S3.Request.t()

  # Client functions

  def start_link() do
    GenServer.start_link(__MODULE__, %{})
  end

  def request_process(pid, req) do
    GenServer.call(pid, {:request, req}, :infinity)
  end

  def stop_process(pid) do
    GenServer.cast(pid, :stop)
  end

  # Server functions

  @impl true
  def init(_) do
    {:ok, %__MODULE__{}}
  end

  @impl true
  def handle_call({:request, req}, from, state) do
    with {:ok, state} <- open_conn(req),
         {:ok, conn, request_ref} <- make_request(state.conn, req) do
      state = put_in(state.conn, conn)
      state = put_in(state.requests[request_ref], %{from: from, response: %{}})
      {:noreply, state}
    else
      {:error, reason} ->
        {:reply, {:error, reason}, state}

      {:error, conn, reason} ->
        state = put_in(state.conn, conn)
        Mint.HTTP.close(state.conn)
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_cast(:stop, state) do
    {:stop, :normal, state}
  end

  @impl true
  def handle_info(message, state) do
    case Mint.HTTP.stream(state.conn, message) do
      :unknown ->
        _ = Logger.error(fn -> "Received unknown message: " <> inspect(message) end)
        {:noreply, state}

      {:error, _, reason, _} ->
        Logger.error(fn -> "Received error message: " <> inspect(reason) end)
        Mint.HTTP.close(state.conn)
        {:reply, {:ok, reason}, state}

      {:ok, conn, responses} ->
        state = put_in(state.conn, conn)
        state = Enum.reduce(responses, state, &process_response/2)
        {:noreply, state}
    end
  end

  defp process_response({:status, request_ref, status}, state) do
    put_in(state.requests[request_ref].response[:status], status)
    #put_in(state, [:requests, request_ref, :response, :status], status)
  end

  defp process_response({:headers, request_ref, headers}, state) do
    #put_in(state.requests[request_ref].response[:headers], headers)
    update_in(state.requests[request_ref].response[:headers], &((&1 || []) ++ headers))
  end

  defp process_response({:data, request_ref, data}, state) do
    #update_in(state.requests[request_ref].response[:data], fn data -> (data || "") <> new_data end)
    update_in(state.requests[request_ref].response[:data], &((&1 || "") <> data))
  end

  # When the request is done, we use GenServer.reply/2 to reply to the caller that was
  # blocked waiting on this request.
  defp process_response({:done, request_ref}, state) do
    {%{response: response, from: from}, state} = pop_in(state.requests[request_ref])
    Mint.HTTP.close(state.conn)
    GenServer.reply(from, {:ok, response})
    state
  end

  #@spec connect(req :: request()) :: {:ok, any()} | {:error, any()}
  defp open_conn(req) do
    case Mint.HTTP.connect(req.scheme, req.host, req.port, [transport_opts: [timeout: 5000]]) do
      {:ok, conn} ->
        state = %__MODULE__{conn: conn}
        {:ok, state}

      {:error, reason} ->
        {:error, reason}
    end
  end

  #@spec execute(conn :: Mint.HTTP.t(), req :: request()) :: {:ok, Mint.HTTP.t(), Mint.Types.request_ref()} | {:error, any()}
  defp make_request(conn, req) do
    path = "#{req.path}?#{URI.encode_query(req.query)}"
    Mint.HTTP.request(conn, req.method, path, req.headers, req.body)
  end
end
