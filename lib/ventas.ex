defmodule Libremarket.Ventas do
  def inicializar_productos() do
    # Al menos 10 productos distintos
    productos =
      for id <- 1..10, into: %{} do
        {
          id,
          %{
            nombre: "Producto #{id}",
            # Stock aleatorio entre 1 y 10
            stock: Enum.random(1..10),
            # Al menos 2 vendedores
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

  # API del cliente

  @doc """
  Inicia el servidor de ventas
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Reserva un producto
  """
  def reservar_producto(pid \\ __MODULE__, id, id_compra) do
    GenServer.call(pid, {:reservar, id, id_compra})
  end

  @doc """
  Libera un producto reservado
  """
  def liberar_producto(pid \\ __MODULE__, id_compra) do
    GenServer.call(pid, {:liberar, id_compra})
  end

  @doc """
  Envía un producto reservado
  """
  def enviar_producto(pid \\ __MODULE__, id_compra) do
    GenServer.call(pid, {:enviar, id_compra})
  end

  @doc """
  Lista los productos disponibles
  """
  def listar_productos(pid \\ __MODULE__) do
    GenServer.call(pid, :listar_productos)
  end

  @doc """
  Lista los productos reservados
  """
  def listar_reservados(pid \\ __MODULE__) do
    GenServer.call(pid, :listar_reservados)
  end

  # Callbacks

  @doc """
  Inicializa el estado del servidor con productos y reservados
  """
  @impl true
  def init(_opts) do
    productos = Libremarket.Ventas.inicializar_productos()
    reservados = %{}
    {:ok, %{productos: productos, reservados: reservados}}
  end

  @doc """
  Callback para manejar la reserva de productos
  """
  @impl true
  def handle_call({:reservar, id, id_compra}, _from, state) do
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
end
