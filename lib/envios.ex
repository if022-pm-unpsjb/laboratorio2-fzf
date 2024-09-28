defmodule Libremarket.Envios do
  def calcular_costo(id) do
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
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def calcular_costo(pid \\ __MODULE__, id) do
    GenServer.call(pid, {:calcular, id})
  end

  def agendar_envio(pid \\ __MODULE__, id) do
    GenServer.call(pid, {:agendar, id})
  end

  def listar_envios_pendiente(pid \\ __MODULE__) do
    GenServer.call(pid, :listar)
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
    # por ahora solo id pero podria ser tambien como cp o algo asi
    result = Libremarket.Envios.calcular_costo(id)

    new_state1 = Map.put_new(state, id, %{})
    new_compra = Map.put_new(new_state1[id], "costo", result)
    new_state = Map.put(state, id, new_compra)

    {:reply, result, new_state}
  end

  @impl true
  def handle_call(:listar, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_call({:agendar, id}, _from, state) do
    new_compra = Map.put_new(state[id], "Envio", id)
    new_state = Map.put(state, id, new_compra)

    {:reply, new_compra, new_state}
  end
end
