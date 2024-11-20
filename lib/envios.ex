defmodule Libremarket.Envios do
  def calcular_costo() do
    :rand.uniform(1000)
  end

  def agendar_envio() do
    {:ok}
  end
end

defmodule Libremarket.Envios.Server do
  use GenServer
  use AMQP

  @save_interval 60_000
  @dets_file "./data/envios.dets"
  @exchange_name "exchange"
  @queue_name "envios_queue"

  # API del cliente

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: {:global, __MODULE__})
  end

  def calcular_costo(_pid \\ __MODULE__, id) do
    GenServer.call({:global, __MODULE__}, {:calcular, id})
  end

  def agendar_envio(_pid \\ __MODULE__, id) do
    GenServer.call({:global, __MODULE__}, {:agendar, id})
  end

  def listar_envios_pendiente(_pid \\ __MODULE__) do
    GenServer.call({:global, __MODULE__}, :listar)
  end

  # Callbacks

  @impl true
  def init(_opts) do
    state = cargar_estado_dets()
    schedule_save()
    Task.start(fn -> setup_amqp(state) end)
    {:ok, state}
  end

  def call(args, queue) do
    {:ok, connection} =
      Connection.open(
        "amqps://rekattab:qWneI9EOyLomLhU4bEjixy-Mz--IBJsx@codfish.rmq.cloudamqp.com/rekattab",
        ssl_options: [verify: :verify_none]
      )

    {:ok, channel} = Channel.open(connection)

    request = inspect(args)

    Basic.publish(
      channel,
      "",
      queue,
      request,
      reply_to: @queue_name
    )
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

  @impl true
  def handle_call({:calcular, id}, _from, state) do
    result = Libremarket.Envios.calcular_costo()
    new_map = Map.put_new(state, id, %{})
    new_envio = Map.put_new(new_map[id], "costo", result)
    new_state = Map.put(state, id, new_envio)
    {:reply, {id, "costo", result}, new_state}
  end

  @impl true
  def handle_call(:listar, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_call({:agendar, id}, _from, state) do
    result = Libremarket.Envios.agendar_envio()
    new_envio = Map.put_new(state[id], "Envio", result)
    new_state = Map.put(state, id, new_envio)
    call({:no_reply, {:enviar, id}}, "ventas_queue")
    {:reply, new_envio, new_state}
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
