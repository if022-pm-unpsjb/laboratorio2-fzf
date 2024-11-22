defmodule Automator do
  def realizar_compra(id_compra, id_producto, metodo_entrega, metodo_pago) do
    Libremarket.Compras.Server.iniciar_comprar(id_compra)
    Libremarket.Compras.Server.seleccionar_producto(id_compra, id_producto)
    Libremarket.Compras.Server.seleccionar_entrega(id_compra, metodo_entrega)
    Libremarket.Compras.Server.seleccionar_pago(id_compra, metodo_pago)
    Libremarket.Compras.Server.confirmar_compra2(id_compra)
  end

  def hacer_compras(cantidad_compras) do
    resultados =
      1..cantidad_compras
      |> Enum.map(fn _ ->
        id_compra = :rand.uniform(1000)
        id_producto = :rand.uniform(15)
        metodoDeEntrega = seleccionar_entrega()
        metodoDePago = seleccionar_pago()
        realizar_compra(id_compra, id_producto, metodoDeEntrega, metodoDePago)
      end)

    resultados
  end

  def hacer_compras_async(cantidad_compras) do
      for _ <- 1..cantidad_compras do
        spawn (fn ->
        id_compra = :rand.uniform(1000)
        id_producto = :rand.uniform(11)
        metodoDeEntrega = seleccionar_entrega()
        metodoDePago = seleccionar_pago()

        realizar_compra(id_compra, id_producto, metodoDeEntrega, metodoDePago)

      end)

    end


  end

  def seleccionar_pago() do
    opciones_pago = [:debito, :credito, :transferencia]
    Enum.random(opciones_pago)
  end

  def seleccionar_entrega() do
    x = :rand.uniform(100)

    if x >= 20 do
      "correo"
    else
      "retiro"
    end
  end
end
