# En este modulo, cada vez que se usa id, es el id de COMPRA
# los demas se especifican como id_producto
defmodule Libremarket.Compras do

  def comprar() do
    {:show_me_the_money}
  end

  def seleccionar_producto() do
    {:select_items}
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
      {:error}
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

  def confirmar_pago(pid \\ __MODULE__) do
    GenServer.call(pid, :confirmar_compra)
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
    new_compra = Map.put_new(state[id],"inf", infraccion)
    new_state = Map.put(state,id,new_compra)
    Libremarket.Compras.seleccionar_entrega()
    {:reply, new_compra, new_state}
  end

  def handle_call({:seleccionar_entrega,id}, _from, state) do
    metodo_entrega = Libremarket.Compras.seleccionar_entrega()
    case metodo_entrega do
      {:ok, "correo"} -> costo = Libremarket.Envios.Server.calcular_costo()
      new_c = Map.put_new(state[id],"costo", costo)
      state = Map.put(state,id,new_c)
      #{:ok, "retiro"} -> Libremarket.Compras.Server.seleccionar_pago()
    end
    new_compra = Map.put_new(state[id],"entrega", metodo_entrega)
    new_state = Map.put(state,id,new_compra)
    #Libremarket.Compras.Server.seleccionar_pago(id) 
    {:reply, new_compra, new_state}
  end

  def handle_call({:seleccionar_pago,id}, _from, state) do
    #estara bien devolver esto?
    {:reply, state, state}
  end

  def handle_call(:confirmar_compra, _from, state) do
    result = Libremarket.Compras.confirmar_compra()
    # aca deberia buscar en el estado, con el id de compra, al resultado del la consulta de infracciones
    {:reply, result, state}
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

