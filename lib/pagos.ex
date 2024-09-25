defmodule Libremarket.Pagos do

  def autorizar() do
    x = :rand.uniform(100)
    if (x>=30) do
      true
    else
      false 
    end
  end

end

defmodule Libremarket.Pagos.Server do
  @moduledoc """
  Pagos
  """

  use GenServer

  # API del cliente

  @doc """
  Crea un nuevo servidor de Pagos
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def autorizar(pid \\ __MODULE__, id) do
    GenServer.call(pid, {:autorizar,id})
  end

  def inspeccionar(pid \\ __MODULE__, id) do
    GenServer.call(pid, {:inspeccionar,id})
  end

  def listar_pagos(pid \\ __MODULE__) do
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
  Callback para un call :autorizar
  """
  @impl true
  def handle_call({:autorizar,id}, _from, state) do
    result = Libremarket.Pagos.autorizar()
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
