defmodule ConsumerTest do
  @moduledoc """
  test consumer
  """
  use ExUnit.Case

  alias ExRocketmq.Consumer
  alias ExRocketmq.Models.Message
  alias ExRocketmq.Namesrvs
  alias ExRocketmq.Transport

  setup_all do
    configs = Application.get_all_env(:ex_rocketmq)

    {host, port} = configs[:namesrvs]
    %{group: group, topic: topic} = configs[:consumer]

    namesrvs_opts = [
      remotes: [
        [transport: Transport.Tcp.new(host: host, port: port)]
      ]
    ]

    namesrvs = start_supervised!({Namesrvs, namesrvs_opts})

    opts = [
      consumer_group: group,
      namesrvs: namesrvs,
      processor: %ExRocketmq.Consumer.MockProcessor{},
      subscriptions: %{
        topic => Models.MsgSelector.new(:tag, "*"),
        "POETRY" => Models.MsgSelector.new(:tag, "*")
      }
    ]

    pid = start_supervised!({Consumer, opts})
    [consumer: pid, topic: topic, group: group]
  end
end
