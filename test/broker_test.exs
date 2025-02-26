defmodule BrokerTest do
  @moduledoc """
  Test broker
  """
  use ExUnit.Case

  alias ExRocketmq.Broker
  alias ExRocketmq.Consumer
  alias ExRocketmq.Models
  alias ExRocketmq.Namesrvs
  alias ExRocketmq.Transport
  alias ExRocketmq.Util.Debug

  setup_all do
    configs = Application.get_all_env(:ex_rocketmq)

    {host, port} = configs[:namesrvs]
    %{group: group, topic: topic} = configs[:consumer]
    [{broker_name, {broker_host, broker_port}}] = configs[:brokers]

    opts = [
      broker_name: broker_name,
      remote_opts: [transport: Transport.Tcp.new(host: broker_host, port: broker_port)]
    ]

    pid = start_supervised!({Broker, opts})

    # TODO define nameserv、consumer
    namesrvs_opts = [
      remotes: [
        [transport: Transport.Tcp.new(host: host, port: port)]
      ]
    ]

    namesrvs = start_supervised!({Namesrvs, namesrvs_opts})

    consumer =
      start_supervised!(
        {Consumer,
         [
           consumer_group: group,
           namesrvs: namesrvs,
           processor: %ExRocketmq.Consumer.MockProcessor{},
           subscriptions: %{
             topic => Models.MsgSelector.new(:tag, "*"),
             "POETRY" => Models.MsgSelector.new(:tag, "*")
           }
         ]}
      )

    [broker: pid, topic: topic, group: group, broker_name: broker_name, consumer: consumer]
  end

  test "send_hearbeat", %{broker: broker, group: group, topic: topic} do
    assert :ok ==
             Broker.heartbeat(broker, %Models.Heartbeat{
               client_id: "test",
               producer_data_set: [
                 %Models.ProducerData{group: "test"}
               ],
               consumer_data_set: [
                 %Models.ConsumerData{
                   group: group,
                   consume_type: "CONSUME_ACTIVELY",
                   message_model: "Clustering",
                   consume_from_where: "CONSUME_FROM_LAST_OFFSET",
                   subscription_data_set: [
                     %Models.Subscription{
                       class_filter_mode: true,
                       topic: topic,
                       sub_string: "*",
                       tags_set: [],
                       code_set: [],
                       sub_version: 0,
                       expression_type: "TAG"
                     }
                   ],
                   unit_mode: false
                 }
               ]
             })
  end

  test "sync_send_message", %{broker: broker, topic: topic} do
    msg = %Models.Message{
      body: "Sync: Hello Elixir",
      flag: 0,
      transaction_id: "",
      batch: false,
      compress: false,
      properties: %{}
    }

    assert {:ok, _resp} =
             Broker.sync_send_message(
               broker,
               %Models.SendMsg.Request{
                 producer_group: "test",
                 topic: topic,
                 queue_id: 1,
                 sys_flag: 0,
                 born_timestamp: :os.system_time(:millisecond),
                 flag: msg.flag,
                 properties: Models.Message.encode_properties(msg),
                 reconsume_times: 0,
                 unit_mode: false,
                 max_reconsume_times: 0,
                 batch: msg.batch,
                 default_topic: "TBW102",
                 default_topic_queue_num: 4
               },
               msg.body
             )
  end

  test "one_way_send_message", %{broker: broker, topic: topic} do
    msg = %Models.Message{
      body: "One Way: Hello Elixir",
      flag: 0,
      transaction_id: "",
      batch: false,
      compress: false,
      properties: %{}
    }

    assert :ok ==
             Broker.one_way_send_message(
               broker,
               %Models.SendMsg.Request{
                 producer_group: "test",
                 topic: topic,
                 queue_id: 1,
                 sys_flag: 0,
                 born_timestamp: :os.system_time(:millisecond),
                 flag: msg.flag,
                 properties: Models.Message.encode_properties(msg),
                 reconsume_times: 0,
                 unit_mode: false,
                 max_reconsume_times: 0,
                 batch: msg.batch,
                 default_topic: "TBW102",
                 default_topic_queue_num: 4
               },
               msg.body
             )
  end

  test "pull_message", %{broker: broker, topic: topic, group: group} do
    assert {:ok, _} =
             broker
             |> Broker.pull_message(%Models.PullMsg.Request{
               consumer_group: group,
               topic: topic,
               queue_id: 0,
               queue_offset: 0,
               max_msg_nums: 32,
               sys_flag: 0,
               commit_offset: 0,
               suspend_timeout_millis: 20_000,
               sub_expression: "*",
               sub_version: 0,
               expression_type: "TAG"
             })
             |> Debug.debug()
  end

  @tag :must_exec
  test "query_consumer_offset", %{broker: broker, topic: topic, group: group} do
    assert {:ok, _} =
             broker
             |> Broker.query_consumer_offset(%Models.QueryConsumerOffset{
               consumer_group: group,
               topic: "WANQIANG_TEST",
               queue_id: 1
             })
             |> Debug.debug()
  end

  test "search_offset_by_timestamp", %{broker: broker, topic: topic} do
    assert {:ok, _} =
             Broker.search_offset_by_timestamp(
               broker,
               %Models.SearchOffset{
                 topic: topic,
                 queue_id: 1,
                 timestamp: :os.system_time(:millisecond)
               }
             )
  end

  test "get_max_offset", %{broker: broker, topic: topic} do
    assert {:ok, _} =
             Broker.get_max_offset(
               broker,
               %Models.GetMaxOffset{
                 topic: topic,
                 queue_id: 1
               }
             )
  end

  test "update_consumer_offset", %{broker: broker, topic: topic, group: group} do
    assert {:ok, offset} =
             Broker.get_max_offset(
               broker,
               %Models.GetMaxOffset{
                 topic: topic,
                 queue_id: 1
               }
             )

    assert :ok ==
             Broker.update_consumer_offset(
               broker,
               %Models.UpdateConsumerOffset{
                 consumer_group: group,
                 topic: topic,
                 queue_id: 1,
                 commit_offset: offset - 10
               }
             )
  end

  test "consumer_send_msg_back", %{broker: broker, topic: topic, group: group} do
    assert :ok ==
             Broker.consumer_send_msg_back(
               broker,
               %Models.ConsumerSendMsgBack{
                 group: group,
                 offset: 0,
                 delay_level: 1,
                 origin_msg_id: "31302E38382E342E3237000051AF000A91F9",
                 origin_topic: topic,
                 max_reconsume_times: 3
               }
             )
  end

  test "get_consumer_list_by_group", %{broker: broker, group: group} do
    assert {:ok, _} = Broker.get_consumer_list_by_group(broker, group)
  end

  # test "end_transaction", %{broker: broker, topic: topic, group: group} do
  #   assert :ok =
  #            Broker.end_transaction(
  #              broker,
  #              %Models.EndTransaction{
  #                producer_group: group,
  #                tran_state_table_offset: 0,
  #                commit_log_offset: 0,
  #                commit_or_rollback: 0,
  #                from_transaction_check: false,
  #                msg_id: "31302E38382E342E3237000051AF000A91F9",
  #                transaction_id: "test"
  #              }
  #            )
  # end

  test "lock_batch_mq", %{broker: broker, topic: topic, group: group, broker_name: broker_name} do
    req = %Models.Lock.Req{
      consumer_group: group,
      client_id: "test",
      mq: [
        %Models.MessageQueue{
          topic: topic,
          broker_name: broker_name,
          queue_id: 0
        }
      ]
    }

    assert {:ok, _} =
             broker
             |> Broker.lock_batch_mq(req)
             |> Debug.debug()

    assert :ok =
             broker
             |> Broker.unlock_batch_mq(req)
             |> Debug.debug()
  end
end
