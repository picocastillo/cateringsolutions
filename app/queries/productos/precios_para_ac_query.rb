module Productos
  class PreciosParaAcQuery < ApplicationQuery
    attr_accessor :nombre, :current_user, :cuenta

    def relation
      return if current_user.cliente?

      q = Productos::Producto.active.where(tienda_id: current_user.tienda_activa)
                             .order(:nombre).joins(:categoria)
                             .merge(Productos::Categoria.where(tienda_id: current_user.tienda_activa).active)
                             .includes(precios: :clientes)
      if cuenta.present?
        q = q.where(categoria_id: cuenta.cliente.categorias.map(&:id)) if cuenta.cliente.categorias.present?
        if nombre.present?
          params = {}
          where_string = ''
          if (textos = nombre.to_s.split.compact_blank).present?
            where_string = [
              where_string, textos.map.with_index do |_, i|
                              "productos.nombre like :texto_#{i}"
                            end.join(' and '), textos.map.with_index do |_, i|
                                                 "productos.codigo like :texto_#{i}"
                                               end.join(' and '),
              textos.map.with_index { |_, i| "productos.codigos_externos like :texto_#{i}" }.join(' and ')
            ].compact_blank.join(' or ')
            textos.each.with_index { |t, i| params[:"texto_#{i}"] = "%#{t}%" }
          end
          q = q.where where_string, params
        end
      end
      q
    end
  end
end
