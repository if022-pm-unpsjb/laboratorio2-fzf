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

  @save_interval 60_000
  @dets_file "./data/envios.dets"

  # API del cliente

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: {:global, __MODULE__})
  end

  def calcular_costo(pid \\ __MODULE__, id) do
    GenServer.call({:global, __MODULE__}, {:calcular, id})
  end

  def agendar_envio(pid \\ __MODULE__, id) do
    GenServer.call({:global, __MODULE__}, {:agendar, id})
  end

  def listar_envios_pendiente(pid \\ __MODULE__) do
    GenServer.call({:global, __MODULE__}, :listar)
  end

  # Callbacks

  @impl true
  def init(_opts) do
    state = cargar_estado_dets()
    schedule_save()
    {:ok, state}
  end

  @impl true
  def handle_call({:calcular, id}, _from, state) do
    result = Libremarket.Envios.calcular_costo()
    new_map = Map.put_new(state, id, %{})
    new_envio = Map.put_new(new_map[id], "costo", result)
    new_state = Map.put(state, id, new_envio)
    {:reply, result, new_state}
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
    # Libremarket.Ventas.Server.enviar_producto(id)
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
