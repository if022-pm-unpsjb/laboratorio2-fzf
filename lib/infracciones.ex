defmodule Libremarket.Infracciones do
  def detectar() do
    x = :rand.uniform(100)

    if x >= 30 do
      false
    else
      true
    end
  end
end

defmodule Libremarket.Infracciones.Server do
  @moduledoc """
  Infracciones
  """

  use GenServer
  use AMQP

  @save_interval 60_000
  @dets_file "./data/infracciones.dets"
  @exchange_name "exchange"
  @queue_name "infracciones_queue"


  # API del cliente

  @doc """
  Crea un nuevo servidor de Infracciones
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: {:global, __MODULE__})
  end

  def detectar(pid \\ __MODULE__, id) do
    GenServer.call({:global, __MODULE__}, {:detectar, id})
  end

  def inspeccionar(pid \\ __MODULE__, id) do
    GenServer.call({:global, __MODULE__}, {:inspeccionar, id})
  end

  def listar_infracciones(pid \\ __MODULE__) do
    GenServer.call({:global, __MODULE__}, :listar)
  end

  # Callbacks

  @doc """
  Inicializa el estado del servidor
  """
  @impl true
  def init(_opts) do
    state = cargar_estado_dets()
    schedule_save()
    {:ok, connection} = Connection.open("amqps://hfbavdbu:h1LYs1gfBHGJadBA7WE4IhEVcP1vyXpr@albatross.rmq.cloudamqp.com/hfbavdbu", ssl_options: [verify: :verify_none])
    {:ok, channel} = Channel.open(connection)
    Queue.declare(channel, @queue_name, durable: true)
    Exchange.declare(channel, @exchange_name, :direct, durable: true)

    # Enlazar la cola con el exchange
    Queue.bind(channel, @queue_name, @exchange_name)

    # Publicar el mensaje
    Basic.consume(channel, @queue_name, nil, no_ack: true)
    receive_messages(channel)

    {:ok, state}
  end

  defp receive_messages(channel) do
    receive do
      {:basic_deliver, payload, _meta} ->
        execute(payload)
        receive_messages(channel)
    end
  end

  def execute(pid \\ __MODULE__, args \\ []) do
    GenServer.call({:global, __MODULE__}, args)
  end

  @doc """
  Callback para un call :detectar
  """
  @impl true
  def handle_call({:detectar, id}, _from, state) do
    result = Libremarket.Infracciones.detectar()
    {:reply, result, [{result, id} | state]}
  end

  @impl true
  def handle_call(:listar, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_call({:inspeccionar, id}, _from, state) do
    result = raise("ops")
    {:reply, result, [{result, id} | state]}
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
