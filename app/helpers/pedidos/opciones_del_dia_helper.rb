module Pedidos
  module OpcionesDelDiaHelper
    # Returns an array of [menu_diario, precios] pairs, one per
    # `productos_diarios` MenuDiario for the pedido's fecha. `precios` is the
    # ordered list of `Productos::Precio` objects each producto resolves to via
    # `Producto#buscar_precio` for the given `cuenta_activa`.
    #
    # Returns [] when:
    #   - tienda is missing or has `soporta_productos_diarios = false`
    #   - cuenta_activa or pedido fecha are missing
    #   - no `productos_diarios` MenuDiario exists for the fecha
    #   - none of the menus have at least one resolvable precio
    def productos_diarios_para(pedido, cuenta_activa, tienda)
      return [] unless tienda&.soporta_productos_diarios?
      return [] unless cuenta_activa && pedido&.fecha

      mds = MenusDiarios::MenuDiario
            .productos_diarios
            .where(tienda_id: tienda.id, fecha: pedido.fecha, discontinued_at: nil)
            .joins(productos: :categoria)
            .merge(Productos::Producto.active)
            .merge(Productos::Categoria.active)
            .includes(productos: [:precios, :categoria, :imagenes])
            .group(:id)

      cliente = cuenta_activa.cliente
      mds = mds.where(productos: { categoria_id: cliente.categorias.map(&:id) }) if cliente.categorias.present?

      mds.map { |md| [md, md.productos.map { |p| p.buscar_precio(cliente, pedido.fecha) }.compact] }
         .reject { |(_md, precios)| precios.empty? }
    end
  end
end
