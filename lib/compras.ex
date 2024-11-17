defmodule Libremarket.Compras do
  def informar_infraccion() do
    {:infraccion_informada}
  end

  def informar_pago_rechazado() do
    {:pago_rechazado_informado}
  end

  def confirmar_compra() do
    x = :rand.uniform(100)

    if x >= 30 do
      true
    else
      false
    end
  end
end

defmodule Libremarket.Compras.Server do
  @moduledoc """
  Compras
  """
  use GenServer
  use AMQP

  @save_interval 60_000
  @dets_file "./data/compras.dets"
  @exchange_name "exchange"
  @queue_name "compras_queue"

  # API del cliente

  @doc """
  Crea un nuevo servidor de Compras
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: {:global, __MODULE__})
  end

  def iniciar_comprar(_pid \\ __MODULE__, id) do
    GenServer.call({:global, __MODULE__}, {:iniciar_comprar, id})
  end

  def seleccionar_producto(_pid \\ __MODULE__, id, id_producto) do
    GenServer.call({:global, __MODULE__}, {:seleccionar_producto, id, id_producto})
  end

  def seleccionar_entrega(_pid \\ __MODULE__, id, metodo_entrega) do
    GenServer.call({:global, __MODULE__}, {:seleccionar_entrega, id, metodo_entrega})
  end

  def seleccionar_pago(_pid \\ __MODULE__, id, metodo_pago) do
    GenServer.call({:global, __MODULE__}, {:seleccionar_pago, id, metodo_pago})
  end

  def confirmar_compra(_pid \\ __MODULE__, id) do
    GenServer.call({:global, __MODULE__}, {:confirmar_compra, id})
  end

  def listar(_pid \\ __MODULE__) do
    GenServer.call({:global, __MODULE__}, :listar)
  end

  # Callbacks

  @doc """
  Inicializa el estado del servidor
  """
  @impl true
  def init(_state) do
    # cargar_estado_dets()
    state = %{}
    # schedule_save()

    {:ok, connection} =
      Connection.open(
        "amqps://rekattab:qWneI9EOyLomLhU4bEjixy-Mz--IBJsx@codfish.rmq.cloudamqp.com/rekattab",
        ssl_options: [verify: :verify_none]
      )

    {:ok, channel} = Channel.open(connection)
    Queue.declare(channel, @queue_name, durable: true)

    Exchange.declare(channel, @exchange_name, :direct, durable: true)

    Queue.bind(channel, @queue_name, @exchange_name)

    :ok = Basic.qos(channel, prefetch_count: 10)

    Basic.consume(channel, @queue_name, nil, no_ack: false)

    {:ok, %{compras: state, channel: channel}}
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

  @doc """
  Callback para un call :comprar
  """
  def handle_call({:iniciar_comprar, id}, _from, %{compras: compras, channel: channel} = _state) do
    new_compras = Map.put_new(compras, id, %{})
    {:reply, id, %{compras: new_compras, channel: channel}}
  end

  def handle_call({:seleccionar_producto, id, id_producto}, _from, state) do
    call({:reply, {:detectar, id, id_producto}}, "infracciones_queue")

    call({:no_reply, {:reservar, id_producto, id}}, "ventas_queue")

    {:reply, id, state}
  end

  @impl true
  def handle_call({:seleccionar_entrega, id_compra, metodo_entrega}, _from, state) do
    call({:reply, {:calcular, id_compra}}, "envios_queue")

    compras =
      Map.update(state.compras, id_compra, %{"entrega" => {metodo_entrega, nil}}, fn compra ->
        Map.put(compra, "entrega", {metodo_entrega, nil})
      end)

    {:reply, id_compra, %{state | compras: compras}}
  end

  def handle_call(
        {:seleccionar_pago, id, metodo_pago},
        _from,
        %{compras: compras, channel: channel} = _state
      ) do
    new_compra = Map.put_new(compras[id], "pago", metodo_pago)
    new_compras = Map.put(compras, id, new_compra)
    {:reply, new_compra, %{compras: new_compras, channel: channel}}
  end

  def handle_call({:confirmar_compra, id}, _from, state) do
    result = Libremarket.Compras.confirmar_compra()
    new_compra = Map.put(state[id] || %{}, "confirmacion", result)

    if result == false do
      new_state = Map.put(state, id, new_compra)
      {:reply, new_compra, new_state}
    else
      new_compra =
        case state[id]["infraccion"] do
          false ->
            # ESTA LINEA CON UN CALL (Como esta en seleccionar producto pero seria para pagos)
            autorizacion = Libremarket.Pagos.Server.autorizar(id)
            # la logica siguiente hay que ponerla en el update compras, lo otro no hace falta moverlo
            # DESDE ACA
            if autorizacion do
              case elem(state[id]["entrega"], 0) do
                # ESTA LLAMADA CON NO_REPLY (COMO EN SELECCIONAR PRODUCTO) ASI QUE NO NECESITA UN UPDATE_COMPRAS PARA ATAJAR LA RESPUESTA
                "correo" -> Libremarket.Envios.Server.agendar_envio(id)
                _ -> :ok
              end
            else
              Libremarket.Compras.informar_pago_rechazado()
              # ESTE TAMBIEN CON NO_REPLY
              Libremarket.Ventas.Server.liberar_producto(id)
            end

            Map.put(new_compra, "autorizacion", autorizacion)

            # HASTA ACA, deberia estar en el update compras para atajar el call de autorizar.
          true ->
            Libremarket.Compras.informar_infraccion()
            # ESTE TAMBIEN CON NO_REPLY, NO HACE FALTA MOVERLO DE ACA
            Libremarket.Ventas.Server.liberar_producto(id)
            new_compra
        end

      new_state = Map.put(state, id, new_compra)
      {:reply, new_compra, new_state}
    end
  end

  @impl true
  def handle_call(:listar, _from, %{compras: compras} = state) do
    {:reply, compras, state}
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

  def handle_info({:basic_consume_ok, %{consumer_tag: _consumer_tag}}, state) do
    {:noreply, state}
  end

  def handle_info({:basic_cancel_ok, %{consumer_tag: _consumer_tag}}, state) do
    {:noreply, state}
  end

  def handle_info({:basic_cancel, %{consumer_tag: _consumer_tag}}, state) do
    {:stop, :normal, state}
  end

  @impl true
  def handle_info(
        {:basic_deliver, payload, %{delivery_tag: tag, redelivered: redelivered}},
        %{compras: compras, channel: channel} = state
      ) do
    new_state = consume(channel, tag, redelivered, payload, state)
    {:noreply, new_state}
  end

  defp consume(channel, tag, _redelivered, payload, state) do
    try do
      IO.puts("Payload recibido: #{inspect(payload)}")

      data =
        case payload do
          _ when is_binary(payload) ->
            {parsed, _} = Code.eval_string(payload)
            parsed

          _ ->
            raise ArgumentError, "Formato de payload no soportado: #{inspect(payload)}"
        end

      updated_state = update_compras(data, state)
      :ok = Basic.ack(channel, tag)
      updated_state
    rescue
      exception ->
        IO.puts("Error processing payload #{inspect(payload)}: #{inspect(exception)}")
        Basic.reject(channel, tag, requeue: false)
        state
    end
  end

  defp update_compras({id_compra, infraccion}, state) do
    new_compras =
      Map.update(state.compras, id_compra, %{"infraccion" => infraccion}, fn compra ->
        Map.put(compra, "infraccion", infraccion)
      end)

    %{state | compras: new_compras}
  end

  defp update_compras({id_compra, "costo", costo}, %{compras: compras} = state) do
    compras_actualizadas =
      Map.update(compras, id_compra, %{}, fn
        %{"entrega" => {metodo_entrega, _}} = compra ->
          IO.puts(metodo_entrega)

          case metodo_entrega do
            "correo" -> Map.put(compra, "entrega", {metodo_entrega, costo})
            "retiro" -> Map.put(compra, "entrega", {metodo_entrega, 0})
            _ -> compra
          end

        compra ->
          compra
      end)

    %{state | compras: compras_actualizadas}
  end
end
