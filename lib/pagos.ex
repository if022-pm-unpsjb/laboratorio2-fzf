defmodule Libremarket.Pagos do
  def autorizar() do
    x = :rand.uniform(100)

    if x >= 30 do
      true
    else
      false
    end
  end
end

defmodule Libremarket.Pagos.Server do
  @moduledoc """
  Pagos
  """

  use GenServer
  use AMQP

  @save_interval 60_000
  @dets_file "./data/pagos.dets"
  @exchange_name "exchange"
  @queue_name "pagos_queue"

  # API del cliente

  @doc """
  Crea un nuevo servidor de Pagos
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: {:global, __MODULE__})
  end

  def autorizar(_pid \\ __MODULE__, id) do
    GenServer.call({:global, __MODULE__}, {:autorizar, id})
  end

  def inspeccionar(_pid \\ __MODULE__, id) do
    GenServer.call({:global, __MODULE__}, {:inspeccionar, id})
  end

  def listar_pagos(_pid \\ __MODULE__) do
    GenServer.call({:global, __MODULE__}, :listar)
  end

  # Callbacks

  @doc """
  Inicializa el estado del servidor
  """
  @impl true
  def init(_opts) do
    state = cargar_estado_dets()
    schedule_save()

    # Iniciar la conexión AMQP de manera asíncrona
    Task.start(fn -> setup_amqp(state) end)

    {:ok, state}
  end

  defp setup_amqp(_state) do
    {:ok, connection} =
      Connection.open(
        "amqps://rekattab:qWneI9EOyLomLhU4bEjixy-Mz--IBJsx@codfish.rmq.cloudamqp.com/rekattab",
        ssl_options: [verify: :verify_none]
      )

    {:ok, channel} = Channel.open(connection)
    Queue.declare(channel, @queue_name, durable: true)
    Exchange.declare(channel, @exchange_name, :direct, durable: true)

    Queue.bind(channel, @queue_name, @exchange_name)
    Basic.consume(channel, @queue_name, nil, no_ack: true)

    receive_messages(channel)
  end

  defp receive_messages(channel) do
    receive do
      {:basic_deliver, payload, meta} ->
        # IO.inspect(payload, label: "Received payload")

        # Use Code.eval_string to parse the payload correctly
        {{reply, parsed_payload}, _binding} = Code.eval_string(payload)
        # IO.inspect(parsed_payload, label: "Parsed payload")

        # Ensure parsed_payload is valid before calling execute
        response = execute(parsed_payload)

        case reply do
          :reply -> Basic.publish(channel, "", meta.reply_to, inspect(response))
          _ -> nil
        end

        receive_messages(channel)
    end
  end

  def execute(args \\ []) do
    result = GenServer.call({:global, __MODULE__}, args)
    # IO.puts(result)
    result
  end

  @doc """
  Callback para un call :autorizar
  """
  @impl true
  def handle_call({:autorizar, id}, _from, state) do
    result = Libremarket.Pagos.autorizar()
    {:reply, result, [{result, id} | state]}
  end

  @impl true
  def handle_call(:listar, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_call({:inspeccionar, id}, _from, state) do
    result = raise("ops")
    {:reply, result, [{result, id} | state]}
  end

  @impl true
  def handle_info(:guardar_estado, state) do
    guardar_estado_dets(state)
    schedule_save()
    {:noreply, state}
  end

  defp schedule_save do
    Process.send_after(self(), :guardar_estado, @save_interval)
  end

  defp guardar_estado_dets(state) do
    case :dets.open_file(String.to_atom(@dets_file), type: :set) do
      {:ok, dets_ref} ->
        :dets.insert(dets_ref, {:estado, state})
        :dets.close(dets_ref)

      {:error, _} ->
        nil
    end
  end

  defp cargar_estado_dets do
    case :dets.open_file(String.to_atom(@dets_file), type: :set) do
      {:ok, dets_ref} ->
        case :dets.lookup(dets_ref, :estado) do
          [{:estado, saved_state}] ->
            :dets.close(dets_ref)
            saved_state

          [] ->
            :dets.close(dets_ref)
            %{}
        end

      {:error, _} ->
        %{}
    end
  end
end
