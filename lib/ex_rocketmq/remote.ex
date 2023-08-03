defmodule ExRocketmq.Remote do
  @moduledoc """
  The remote layer of the rocketmq: how client communicates with the nameserver
  """
  alias ExRocketmq.{Transport, Typespecs}

  use GenServer
  require Logger

  defstruct [:name, :transport]

  @type t :: %__MODULE__{
          name: Typespecs.name(),
          transport: Transport.t()
        }

  @spec new(Typespecs.opts()) :: t()
  def new(opts) do
    opts =
      opts
      |> Keyword.put_new(:name, :remote)

    struct(__MODULE__, opts)
  end

  def start_link(remote: remote) do
    GenServer.start_link(__MODULE__, remote, name: remote.name)
  end

  def init(remote) do
    {:ok, %{transport: remote.transport, rpc_store: %{}}, {:continue, :connect}}
  end

  def handle_continue(:connect, %{transport: transport} = state) do
    Logger.debug(%{"msg" => "connecting", "host" => transport.host, "port" => transport.port})

    Transport.start_link(transport)
    |> case do
      {:ok, _pid} ->
        Logger.debug(%{"msg" => "connected", "host" => transport.host, "port" => transport.port})
        Process.send_after(self(), :recv, 0)
        {:noreply, state}

      {:error, reason} ->
        {:stop, reason, state}
    end
  end

  def handle_info(:recv, %{transport: transport} = state) do
    Logger.debug("recv: waiting")

    Transport.recv(transport)
    |> case do
      {:ok, data} ->
        Logger.debug("recv: #{inspect(data)}")
        Process.send_after(self(), :recv, 0)
        {:noreply, state}

      {:error, :timeout} ->
        Process.send_after(self(), :recv, 1000)
        {:noreply, state}

      {:error, reason} ->
        # maybe reconnecting
        Logger.warning(%{"msg" => "recv error", "reason" => inspect(reason)})
        Process.send_after(self(), :recv, 2000)
        {:noreply, state}
    end
  end

  def terminate(reason, state) do
    Logger.warning(%{"msg" => "terminated", "reason" => inspect(reason)})
    {:ok, state}
  end
end
