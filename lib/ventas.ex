defmodule Libremarket.Ventas do
  def inicializar_productos() do
    productos =
      for id <- 1..10, into: %{} do
        {
          id,
          %{
            nombre: "Producto #{id}",
            stock: Enum.random(1..10),
            vendedor: Enum.random([1, 2])
          }
        }
      end

    productos
  end

  def reservar_producto(id, id_compra, %{productos: productos, reservados: reservados}) do
    case Map.get(productos, id) do
      nil ->
        {:error, "Producto no encontrado"}

      %{stock: 0} = producto ->
        {:error, "Sin stock para #{producto.nombre}"}

      producto ->
        productos_actualizados = Map.put(productos, id, %{producto | stock: producto.stock - 1})

        reservados_actualizados =
          Map.put(reservados, id_compra, %{nombre: producto.nombre, id: id})

        {:ok, "Producto #{producto.nombre} reservado",
         %{productos: productos_actualizados, reservados: reservados_actualizados}}
    end
  end

  def liberar_producto(id_compra, %{productos: productos, reservados: reservados}) do
    case Map.get(reservados, id_compra) do
      nil ->
        {:error, "Producto no encontrado"}

      %{id: id} = producto_reservado ->
        producto = Map.get(productos, id)
        productos_actualizados = Map.put(productos, id, %{producto | stock: producto.stock + 1})
        reservados_actualizados = Map.delete(reservados, id_compra)

        {:ok, "Producto #{producto_reservado.nombre} liberado",
         %{productos: productos_actualizados, reservados: reservados_actualizados}}
    end
  end

  def enviar_producto(id_compra, %{productos: productos, reservados: reservados}) do
    case Map.get(reservados, id_compra) do
      nil ->
        {:error, "Producto no encontrado"}

      producto_reservado ->
        reservados_actualizados = Map.delete(reservados, id_compra)

        {:ok, "Producto #{producto_reservado.nombre} enviado",
         %{productos: productos, reservados: reservados_actualizados}}
    end
  end

  def listar_productos(%{productos: productos}) do
    productos
  end

  def listar_reservados(%{reservados: reservados}) do
    reservados
  end
end

defmodule Libremarket.Ventas.Server do
  @moduledoc """
  Servidor de ventas.
  """

  use GenServer
  use AMQP

  @save_interval 60_000
  @dets_file "./data/ventas.dets"

  @exchange_name "exchange"
  @queue_name "ventas_queue"

  # API del cliente

  @doc """
  Inicia el servidor de ventas
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: {:global, __MODULE__})
  end

  @doc """
  Reserva un producto
  """
  def reservar_producto(_pid \\ __MODULE__, id, id_compra) do
    GenServer.call({:global, __MODULE__}, {:reservar, id, id_compra})
  end

  @doc """
  Libera un producto reservado
  """
  def liberar_producto(_pid \\ __MODULE__, id_compra) do
    GenServer.call({:global, __MODULE__}, {:liberar, id_compra})
  end

  @doc """
  Envía un producto reservado
  """
  def enviar_producto(_pid \\ __MODULE__, id_compra) do
    GenServer.call({:global, __MODULE__}, {:enviar, id_compra})
  end

  @doc """
  Lista los productos disponibles
  """
  def listar_productos(_pid \\ __MODULE__) do
    GenServer.call({:global, __MODULE__}, :listar_productos)
  end

  @doc """
  Lista los productos reservados
  """
  def listar_reservados(_pid \\ __MODULE__) do
    GenServer.call({:global, __MODULE__}, :listar_reservados)
  end

  # Callbacks

  @doc """
  Inicializa el estado del servidor con productos y reservados
  """
  @impl true
  def init(_opts) do
    productos = Libremarket.Ventas.inicializar_productos()
    reservados = %{}
    state = %{productos: productos, reservados: reservados}

    # Optionally merge with any loaded state
    state = Map.merge(state, cargar_estado_dets())
    schedule_save()

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
    # Ensure that we are calling the GenServer with the args directly
    result = GenServer.call({:global, __MODULE__}, args)
    # IO.puts(result)
    result
  end

  @doc """
  Callback para manejar la reserva de productos
  """
  @impl true
  def handle_call({:reservar, id, id_compra}, _from, state) do
    IO.puts("si reservo")

    case Libremarket.Ventas.reservar_producto(id, id_compra, state) do
      {:ok, mensaje, nuevo_state} ->
        {:reply, {:ok, mensaje}, nuevo_state}

      {:error, mensaje} ->
        {:reply, {:error, mensaje}, state}
    end
  end

  @impl true
  def handle_call({:liberar, id_compra}, _from, state) do
    case Libremarket.Ventas.liberar_producto(id_compra, state) do
      {:ok, mensaje, nuevo_state} ->
        {:reply, {:ok, mensaje}, nuevo_state}

      {:error, mensaje} ->
        {:reply, {:error, mensaje}, state}
    end
  end

  @impl true
  def handle_call({:enviar, id_compra}, _from, state) do
    IO.puts("si envio producto")

    case Libremarket.Ventas.enviar_producto(id_compra, state) do
      {:ok, mensaje, nuevo_state} ->
        {:reply, {:ok, mensaje}, nuevo_state}

      {:error, mensaje} ->
        {:reply, {:error, mensaje}, state}
    end
  end

  @impl true
  def handle_call(:listar_productos, _from, state) do
    productos = Libremarket.Ventas.listar_productos(state)
    {:reply, productos, state}
  end

  @impl true
  def handle_call(:listar_reservados, _from, state) do
    reservados = Libremarket.Ventas.listar_reservados(state)
    {:reply, reservados, state}
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
