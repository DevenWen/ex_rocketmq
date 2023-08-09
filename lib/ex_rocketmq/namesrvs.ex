defmodule ExRocketmq.Namesrvs do
  @moduledoc """
  The namesrvs layer of the rocketmq: how client communicates with the namesrvs
  """

  use GenServer

  alias ExRocketmq.{Remote, Typespecs, Message, Protocol.Request, Models}

  require Message

  import ExRocketmq.Util.Debug

  @namesrvs_opts_schema [
    name: [
      type: :atom,
      default: __MODULE__,
      doc: "The name of the namesrvs"
    ],
    remote: [
      type: :any,
      required: true,
      doc: "The remote instance of the namesrvs"
    ]
  ]

  defstruct [:name, :remote]

  @type t :: %__MODULE__{
          name: Typespecs.name(),
          remote: Remote.t()
        }

  @type namesrvs_opts_schema_t :: [unquote(NimbleOptions.option_typespec(@namesrvs_opts_schema))]

  @spec new(namesrvs_opts_schema_t()) :: t()
  def new(opts) do
    opts =
      opts
      |> NimbleOptions.validate!(@namesrvs_opts_schema)

    struct(__MODULE__, opts)
  end

  @spec start_link(namesrvs: t()) :: Typespecs.on_start()
  def start_link(namesrvs: namesrvs) do
    GenServer.start_link(__MODULE__, namesrvs, name: namesrvs.name)
  end

  @doc """
  query the topic route info from the namesrvs

  ## Examples

      iex> ExRocketmq.Namesrvs.query_topic_route_info(namesrvs, "topic")
      {:ok,
       %ExRocketmq.Models.TopicRouteInfo{
         broker_datas: [
           %ExRocketmq.Models.BrokerData{
             broker_addrs: %{"0" => "10.88.4.78:20911", "2" => "10.88.4.144:20911"},
             broker_name: "sts-broker-d2-0",
             cluster: "d2"
           }
         ],
         queue_datas: [
           %ExRocketmq.Models.QueueData{
             broker_name: "sts-broker-d2-0",
             perm: 6,
             read_queue_nums: 2,
             topic_syn_flag: 0,
             write_queue_nums: 2
           }
         ]
       }}
  """
  @spec query_topic_route_info(t(), String.t()) ::
          Typespecs.ok_t(Models.TopicRouteInfo.t()) | Typespecs.error_t()
  def query_topic_route_info(namesrvs, topic) do
    with {:ok, msg} <-
           GenServer.call(
             namesrvs.name,
             {:rpc, Request.req_get_routeinfo_by_topic(), <<>>, %{"topic" => topic}}
           ) do
      msg
      |> Message.message(:body)
      |> fix_invalid_json()
      |> Models.TopicRouteInfo.from_json()
      |> then(&{:ok, &1})
    end
  end

  @doc """
  get the broker cluster info from the namesrvs

  ## Examples

      iex> ExRocketmq.Namesrvs.get_broker_cluster_info(namesrvs)
      {:ok,
        %ExRocketmq.Models.BrokerClusterInfo{
          broker_addr_table: %{
            "sts-broker-d2-0" => %ExRocketmq.Models.BrokerData{
              broker_addrs: %{"0" => "10.88.4.57:20911", "1" => "10.88.4.189:20911"},
              broker_name: "sts-broker-d2-0",
              cluster: "d2"
            }
          },
          cluster_addr_table: %{"d2" => ["sts-broker-d2-0"]}
      }}
  """
  @spec get_broker_cluster_info(t()) ::
          Typespecs.ok_t(Models.BrokerClusterInfo.t()) | Typespecs.error_t()
  def get_broker_cluster_info(namesrvs) do
    with {:ok, msg} <-
           GenServer.call(
             namesrvs.name,
             {:rpc, Request.req_get_broker_cluster_info(), <<>>, %{}}
           ) do
      msg
      |> Message.message(:body)
      |> fix_invalid_json()
      |> Models.BrokerClusterInfo.from_json()
      |> then(&{:ok, &1})
    end
  end

  # because of fastjson, brokerAddrs is a integer-keyed map, which is invalid json
  # we replace integer-keyed map with string-keyed map here
  defp fix_invalid_json(input) do
    pattern = ~r/"brokerAddrs":{(\d+:"[^"]+",*)+}/
    matches = Regex.run(pattern, input)

    case matches do
      [] ->
        input

      [brokerAddrs, _] ->
        # "\"brokerAddrs\":{0:\"10.88.4.78:20911\",1:\"10.88.4.79:20911\"}"
        fixedBrokerAddrs =
          brokerAddrs
          |> String.slice(15..-2)
          |> String.split(",")
          |> Enum.map(fn x ->
            [index, addr] = String.split(x, ":", parts: 2)
            "\"#{index}\":#{addr}"
          end)
          |> Enum.join(",")
          |> then(&"\"brokerAddrs\":{#{&1}}")

        String.replace(input, brokerAddrs, fixedBrokerAddrs)
    end
  end

  # -------- server -------

  def init(namesrvs) do
    {:ok, _} = Remote.start_link(remote: namesrvs.remote)
    {:ok, %{namesrvs: namesrvs, opaque: 0}}
  end

  def handle_call(
        {:rpc, code, body, ext_fields},
        _from,
        %{namesrvs: namesrvs, opaque: opaque} = state
      ) do
    msg =
      Message.message(
        code: code,
        opaque: opaque,
        ext_fields: ext_fields,
        body: body
      )

    {:reply, Remote.rpc(namesrvs.remote, msg), %{state | opaque: opaque + 1}}
  end
end
