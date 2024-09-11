# En este modulo, cada vez que se usa id, es el id de COMPRA
# los demas se especifican como id_producto
defmodule Libremarket.Compras do

  def comprar() do
    {:show_me_the_money}
  end

  def iniciar_compra() do
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

  def seleccionar_producto(pid \\ __MODULE__) do
    GenServer.call(pid, :seleccionar_producto)
  end

  def seleccionar_entrega(pid \\ __MODULE__) do
    GenServer.call(pid, :seleccionar_entrega)
  end

  def seleccionar_pago(pid \\ __MODULE__) do
    GenServer.call(pid, :seleccionar_pago)
  end

  # Callbacks
  # EL STATE DE COMPRAS ES LA LISTA DE COMPRAS, como diccionario xddd

  @doc """
  Inicializa el estado del servidor
  """
  @impl true
  def init(state) do
    {:ok, state}
  end

  @doc """
  Callback para un call :comprar
  """
  @impl true
  def handle_call(:comprar, _from, state) do
    result = Libremarket.Compras.comprar
    {:reply, result, state}
  end

  def handle_call({:seleccionar_producto,id,id_producto}, _from, state) do
    Libremarket.Compras.seleccionar_pago()
    Libremarket.Compras.Server.confirmar_compra()
    #estara bien devolver esto?
    {:reply, state, state}
  end

  def handle_call(:seleccionar_entrega, _from, state) do
    metodo_entrega = Libremarket.Compras.seleccionar_entrega()
    case metodo_entrega do
      {:ok, "correo"} -> Libremarket.Envios.Server.calcular_costo() 
      # falta llamar a seleccionar pago desde aca no?
      # tambien deberia guardar en el esto que responde 
      {:ok, "retiro"} -> Libremarket.Compras.Server.seleccionar_pago()
    {:reply, state, state}
  end

  def handle_call(:seleccionar_pago, _from, state) do
    Libremarket.Compras.seleccionar_pago()
    Libremarket.Compras.Server.confirmar_compra()
    #estara bien devolver esto?
    {:reply, state, state}
  end

  def handle_call(:confirmar_compra, _from, state) do
    result = Libremarket.Compras.confirmar_compra()
    # aca deberia buscar en el estado, con el id de compra, al resultado del la consulta de infracciones
    {:reply, result, state}
  end



    """
    notix:
      esto empieza con iniciar compra, me devuelve un id, que yo se lo pase tambien ese id,
    ahi inicia un diccionario con ese id,
    Despues le hago el seleccionar_producto, le paso el id del producto y el id de la compra

    seria como stateless

    """
end

