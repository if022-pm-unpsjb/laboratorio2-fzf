# En este modulo, cada vez que se usa id, es el id de COMPRA
# los demas se especifican como id_producto
defmodule Libremarket.Compras do

  def comprar() do
    {:show_me_the_money}
  end

  def seleccionar_producto() do
    {:select_items}
  end

  def informar_infraccion() do
    {:infraccion_informada}
  end

  def informar_pago_rechazado() do
    {:pago_rechazado_informado}
  end

  def seleccionar_entrega() do
    x = :rand.uniform(100)
    if (x>=20) do
      {:ok,"correo"}
    else
      {:ok,"retiro"}
    end
  end

  def confirmar_compra() do
    x = :rand.uniform(100)
    if (x>=30) do
      # confirma la compra
      {:ok}
    else
      # no confirma la compra
      {:cancel}
    end
  end

  def seleccionar_pago() do
    {:metodo_de_pago}
  end
end

defmodule Libremarket.Compras.Server do
  @moduledoc """
  Compras
  """
  use GenServer

  # API del cliente

  @doc """
  Crea un nuevo servidor de Compras
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def comprar(pid \\ __MODULE__) do
    GenServer.call(pid, :comprar)
  end

  def iniciar_comprar(pid \\ __MODULE__, id) do
    GenServer.call(pid, {:iniciar_comprar, id})
  end

  def seleccionar_producto(pid \\ __MODULE__,id,id_producto) do
    GenServer.call(pid, {:seleccionar_producto,id,id_producto})
  end

  def seleccionar_entrega(pid \\ __MODULE__,id) do
    GenServer.call(pid, {:seleccionar_entrega,id})
  end

  def seleccionar_pago(pid \\ __MODULE__, id) do
    GenServer.call(pid, {:seleccionar_pago, id})
  end

  def confirmar_compra(pid \\ __MODULE__,id) do
    GenServer.call(pid, {:confirmar_compra,id})
  end

  def listar(pid \\ __MODULE__) do
    GenServer.call(pid, :listar)
  end

  # Callbacks
  # EL STATE DE COMPRAS ES LA LISTA DE COMPRAS, como diccionario xddd

  @doc """
  Inicializa el estado del servidor
  """
  @impl true
  def init(_state) do
    {:ok, %{}}
  end

  @doc """
  Callback para un call :comprar
  """
  @impl true
  def handle_call(:comprar, _from, state) do
    result = Libremarket.Compras.comprar
    {:reply, result, state}
  end

  def handle_call({:iniciar_comprar,id}, _from, state) do
    new_state = Map.put_new(state,id,%{})
    {:reply, id, new_state}
  end

  def handle_call({:seleccionar_producto,id,id_producto}, _from, state) do
    # falta llamar a reservar producto
    infraccion = Libremarket.Infracciones.Server.detectar(id_producto)
    new_compra = Map.put_new(state[id],"infraccion", infraccion)
    new_state = Map.put(state,id,new_compra)
    {:reply, new_compra, new_state}
  end

  # falta sacarle los ok que quedan en el mapa
  def handle_call({:seleccionar_entrega,id}, _from, state) do
    metodo_entrega = Libremarket.Compras.seleccionar_entrega()
    costo =
    case metodo_entrega do
      {:ok, "correo"} -> Libremarket.Envios.Server.calcular_costo(id)
      {:ok, "retiro"} -> 0
      _-> 0
    end
	new_compra =
		(state[id] || %{})
		|> Map.put_new("entrega", {metodo_entrega, costo})
		|> Map.put("pago", Libremarket.Compras.seleccionar_pago())

	new_state = Map.put(state,id,new_compra)
	{:reply, new_compra, new_state}
  end

  """
  # no lo uso realmente, lo llamo en seleccionar entrega, por que este es automatico xddd
  def handle_call({:seleccionar_pago,id}, _from, state) do
    {:reply, state, state}
  end
  """

  def handle_call({:confirmar_compra, id}, _from, state) do
    result = Libremarket.Compras.confirmar_compra()
	new_compra=Map.put_new(state[id],"confirmacion", result)
	case (state[id])["infraccion"] do
		{:ok}-> autorizacion= Libremarket.Pagos.Server.autorizar(id) 
		new_compra = Map.put(new_compra, "autorizacion", autorizacion)
		IO.puts("opcion con ok")
		{:infraccion} -> Libremarket.Compras.informar_infraccion() 
        IO.puts("opcion con infraccion")
	end

	new_state= Map.put(state,id,new_compra)
    {:reply, new_compra, new_state}
  end

  @impl true
  def handle_call(:listar, _from, state) do
    {:reply, state, state}
  end

    """
    notix:
      esto empieza con iniciar compra, me devuelve un id, que yo se lo pase tambien ese id,
    ahi inicia un diccionario con ese id,
    Despues le hago el seleccionar_producto, le paso el id del producto y el id de la compra

    seria como stateless

    """
end

