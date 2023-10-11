defmodule ExRocketmq.Producer.Transaction do
  @moduledoc """
  tranaction behavior
  """
  alias ExRocketmq.{Typespecs, Models}

  @type t :: struct()

  @callback execute_local(m :: t(), msg :: Models.Message.t()) ::
              {:ok, Typespecs.transaction_state()} | Typespecs.error_t()
  @callback check_local(m :: t(), msg :: Models.MessageExt.t()) ::
              {:ok, Typespecs.transaction_state()} | Typespecs.error_t()

  defp delegate(%module{} = m, func, args),
    do: apply(module, func, [m | args])

  @doc """
  execute local transaction before commit to broker
  """
  @spec execute_local(t(), Models.Message.t()) ::
          {:ok, Typespecs.transaction_state()} | Typespecs.error_t()
  def execute_local(m, msg), do: delegate(m, :execute_local, [msg])

  @doc """
  check if local transaction is ok or not
  """
  @spec check_local(t(), Models.MessageExt.t()) ::
          {:ok, Typespecs.transaction_state()} | Typespecs.error_t()
  def check_local(m, msg), do: delegate(m, :check_local, [msg])
end
