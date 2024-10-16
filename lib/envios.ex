defmodule Libremarket.Envios do
  def calcular_costo() do
    :rand.uniform(1000)
  end

  def agendar_envio() do
    {:ok}
  end
end

defmodule Libremarket.Envios.Server do
  @moduledoc """
  Envios
  """

  use GenServer

  # API del cliente

  @doc """
  Crea un nuevo servidor de Envios
  """
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

  @doc """
  Inicializa el estado del servidor
  """
  @impl true
  def init(_state) do
    {:ok, %{}}
  end

  @doc """
  Callback para un call :detectar
  """
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
    Libremarket.Ventas.Server.enviar_producto(id)
    {:reply, new_envio, new_state}
  end
end
