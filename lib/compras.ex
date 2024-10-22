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
    opciones_pago = [:debito, :credito, :transferencia]
    Enum.random(opciones_pago)
  end
end

defmodule Libremarket.Compras.Server do
  @moduledoc """
  Compras
  """
  use GenServer

  @save_interval 60_000
  @dets_file "./data/compras.dets"

  # API del cliente

  @doc """
  Crea un nuevo servidor de Compras
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: {:global, __MODULE__})
  end

  def comprar(pid \\ __MODULE__) do
    GenServer.call({:global, __MODULE__}, :comprar)
  end

  def iniciar_comprar(pid \\ __MODULE__, id) do
    GenServer.call({:global, __MODULE__}, {:iniciar_comprar, id})
  end

  def seleccionar_producto(pid \\ __MODULE__, id, id_producto) do
    GenServer.call({:global, __MODULE__}, {:seleccionar_producto, id, id_producto})
  end

  def seleccionar_entrega(pid \\ __MODULE__, id, metodo_entrega) do
    GenServer.call({:global, __MODULE__}, {:seleccionar_entrega, id, metodo_entrega})
  end

  def seleccionar_pago(pid \\ __MODULE__, id,metodo_pago) do
    GenServer.call({:global, __MODULE__}, {:seleccionar_pago, id,metodo_pago})
  end

  def confirmar_compra(pid \\ __MODULE__, id) do
    GenServer.call({:global, __MODULE__}, {:confirmar_compra, id})
  end

  def listar(pid \\ __MODULE__) do
    GenServer.call({:global, __MODULE__}, :listar)
  end

  # Callbacks

  @doc """
  Inicializa el estado del servidor
  """
  @impl true
  def init(_state) do
    state = cargar_estado_dets()
    schedule_save()
    {:ok, state}
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


  def handle_call({:seleccionar_entrega, id, metodo_entrega}, _from, state) do
    costo =
      case metodo_entrega do
        "correo" -> Libremarket.Envios.Server.calcular_costo(id)
        "retiro" -> 0
        _ -> 0
      end

    new_compra =
      (state[id] || %{})
      |> Map.put_new("entrega", {metodo_entrega, costo})

    new_state = Map.put(state, id, new_compra)
    {:reply, new_compra, new_state}
  end


  def handle_call({:seleccionar_pago, id, metodo_pago},_from, state) do
    new_compra = Map.put_new(state[id], "pago", metodo_pago)
    new_state = Map.put(state, id, new_compra)
    {:reply, new_compra, new_state}
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
            autorizacion = Libremarket.Pagos.Server.autorizar(id)

            if autorizacion do
              case elem(state[id]["entrega"], 0) do
                "correo" -> Libremarket.Envios.Server.agendar_envio(id)
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
