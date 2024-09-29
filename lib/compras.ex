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

    if x >= 20 do
      "correo"
    else
      "retiro"
    end
  end

  def confirmar_compra() do
    x = :rand.uniform(100)

    if x >= 30 do
      # confirma la compra
      true
    else
      # no confirma la compra
      false
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

  def seleccionar_producto(pid \\ __MODULE__, id, id_producto) do
    GenServer.call(pid, {:seleccionar_producto, id, id_producto})
  end

  def seleccionar_entrega(pid \\ __MODULE__, id) do
    GenServer.call(pid, {:seleccionar_entrega, id})
  end

  def seleccionar_pago(pid \\ __MODULE__, id) do
    GenServer.call(pid, {:seleccionar_pago, id})
  end

  def confirmar_compra(pid \\ __MODULE__, id) do
    GenServer.call(pid, {:confirmar_compra, id})
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
    result = Libremarket.Compras.comprar()
    {:reply, result, state}
  end

  def handle_call({:iniciar_comprar, id}, _from, state) do
    new_state = Map.put_new(state, id, %{})
    {:reply, id, new_state}
  end

  def handle_call({:seleccionar_producto, id, id_producto}, _from, state) do
    # TODO: Revisar metodo y llamada
    Libremarket.Ventas.Server.reservar_producto(id_producto, id)
    infraccion = Libremarket.Infracciones.Server.detectar(id_producto)
    new_compra = Map.put_new(state[id], "infraccion", infraccion)
    new_state = Map.put(state, id, new_compra)
    {:reply, new_compra, new_state}
  end

  def handle_call({:seleccionar_entrega, id}, _from, state) do
    metodo_entrega = Libremarket.Compras.seleccionar_entrega()

    costo =
      case metodo_entrega do
        "correo" -> Libremarket.Envios.Server.calcular_costo(id)
        "retiro" -> 0
        _ -> 0
      end

    new_compra =
      (state[id] || %{})
      |> Map.put_new("entrega", {metodo_entrega, costo})
      |> Map.put("pago", Libremarket.Compras.seleccionar_pago())

    new_state = Map.put(state, id, new_compra)
    {:reply, new_compra, new_state}
  end

  def handle_call({:confirmar_compra, id}, _from, state) do
    result = Libremarket.Compras.confirmar_compra()

    if result == false do
      {:reply, Map.put_new(state[id], "confirmacion", result), state}
    else
      new_compra = Map.put_new(state[id], "confirmacion", result)

      new_compra =
        case state[id]["infraccion"] do
          false ->
            autorizacion = Libremarket.Pagos.Server.autorizar(id)

            if autorizacion do
              case elem(state[id]["entrega"], 0) do
                "correo" -> Libremarket.Envios.Server.agendar_envio(id)
                # No hace nada si es "retiro" u otro método
                _ -> :ok
              end
            else
              Libremarket.Compras.informar_pago_rechazado()
              Libremarket.Ventas.Server.liberar_producto(id)
            end

            Map.put(new_compra, "autorizacion", autorizacion)

          true ->
            Libremarket.Compras.informar_infraccion()
            Libremarket.Ventas.Server.liberar_producto(id)
            new_compra
        end

      new_state = Map.put(state, id, new_compra)
      {:reply, new_compra, new_state}
    end
  end

  @impl true
  def handle_call(:listar, _from, state) do
    {:reply, state, state}
  end
end
