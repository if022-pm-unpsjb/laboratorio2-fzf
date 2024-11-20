# Libremarket

Este proyecto está desarrollado en **Elixir**. A continuación, se explica el flujo necesario para realizar una compra en el sistema.

---

## Flujo para Realizar una Compra

El flujo de compra se realiza ejecutando una serie de comandos en la consola. Aquí tienes los pasos necesarios:

1. **Iniciar compra**  
   ```bash
   Libremarket.Compras.Server.iniciar_comprar(id_compra)

2. **Seleccionar Producto**  
   ```bash
   Libremarket.Compras.Server.seleccionar_producto(id_compra, id_producto)

3. **Seleccionar Método de Entrega** (Elegir entre "correo" y "retiro")
   ```bash
   Libremarket.Compras.Server.seleccionar_entraga(id_compra, "Método de entrega")

4. **Seleccionar Método de Pago**  (El argumento es indistinto, podria usar :credito o :debito)
   ```bash
   Libremarket.Compras.Server.seleccionar_pago(id_compra, "Método de pago")

5. **Confirmar Compra**  
   ```bash
   Libremarket.Compras.Server.confirma_compra(id_compra)

---

## Automatización de una Compra

También, es posible realizar una compra a través del siguiente comando:

- **Realizar una Compra**  
   ```bash
   Automator.realizar_compra(id_compra, id_producto, "Método de entrega", "Método de pago")

---

##  Múltiples Compras

Para ejecutar varias compras a la vez, usar este comando indicando la cantidad de compras a realizar:

- **Realizar una Compra**  
   ```bash
   Automator.hacer_compras(cantidad_compras)

---

## Listar Compras

Para visualizar las compras realizadas, ejecutar el siguiente comando:

- **Listar Compras**  
   ```bash
   Libremarket.Compras.Server.listar
