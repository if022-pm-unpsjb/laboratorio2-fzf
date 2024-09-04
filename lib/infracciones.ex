defmodule Libremarket.Infracciones do

  def detectar() do
    x = :rand.uniform(100)
    if (x>=30) do
      {:ok}
    else
      {:error_logger}
    end
  end

end

defmodule Libremarket.Infracciones.Server do
  @moduledoc """
  Infracciones
  """

  use GenServer

  # API del cliente

  @doc """
  Crea un nuevo servidor de Infracciones
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def detectar(pid \\ __MODULE__, id) do
    GenServer.call(pid, {:detectar,id})
  end

  def inspeccionar(pid \\ __MODULE__, id) do
    GenServer.call(pid, {:inspeccionar,id})
  end

  def listar_infracciones(pid \\ __MODULE__) do
    GenServer.call(pid, :listar)
  end


  # Callbacks

  @doc """
  Inicializa el estado del servidor
  """
  @impl true
  def init(state) do
    {:ok, state}
  end

  @doc """
  Callback para un call :detectar
  """
  @impl true
  def handle_call({:detectar,id}, _from, state) do
    result = Libremarket.Infracciones.detectar()
    {:reply, result, [{result,id}| state]}
  end

  @impl true
  def handle_call(:listar, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_call({:inspeccionar,id}, _from, state) do
    result= raise("ops")
    {:reply, result, [{result,id}| state]}
  end



end
