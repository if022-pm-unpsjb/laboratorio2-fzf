defmodule Automator do
  def realizar_compra(id_compra, id_producto) do
    # Iniciar la compra
    case Libremarket.Compras.Server.iniciar_comprar(id_compra) do
      ^id_compra ->
        # Seleccionar el producto
        case Libremarket.Compras.Server.seleccionar_producto(id_compra, id_producto) do
          %{"infraccion" => _} ->
            # Seleccionar entrega
            case Libremarket.Compras.Server.seleccionar_entrega(id_compra) do
              %{"entrega" => {_metodo, _costo}, "pago" => _metodo_de_pago, "infraccion"=> _infraccion} ->
                # Confirmar la compra
                case Libremarket.Compras.Server.confirmar_compra(id_compra) do
                  %{"confirmacion" => true} ->
                    {:ok, "Compra realizada con éxito"}

                  %{"confirmacion" => false} ->
                    {:error, "La compra fue cancelada"}

                  _ ->
                    {:error, "Error al confirmar la compra"}
                end

              _ ->
                {:error, "Error al seleccionar la entrega"}
            end

          _ ->
            {:error, "Error al seleccionar el producto"}
        end

      _ ->
        {:error, "Error al iniciar la compra"}
    end
  end

  # Nueva función para realizar múltiples compras con IDs generados aleatoriamente
  def hacer_compras(cantidad_compras) do
    # Generar una lista de resultados
    resultados =
      1..cantidad_compras
      |> Enum.map(fn _ ->
        id_compra = :rand.uniform(1000)
        id_producto = :rand.uniform(1000)

        realizar_compra(id_compra, id_producto)
      end)

    # Devolver la lista de resultados
    resultados
  end
end
