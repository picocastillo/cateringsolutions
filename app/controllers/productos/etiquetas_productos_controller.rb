module Productos
  class EtiquetasProductosController < ApplicationController
    def index
      authorize! :index, :etiqueta_producto
      @query = ProductosQuery.new query_params.reverse_merge(activo_el: Time.zone.today, dias_vencimiento: 3,
                                                             cantidad: 1)
      respond_to do |format|
        format.html do
          load_data
          if @precio
            redirect_to etiquetas_productos_path(format: :pdf,
                                                 q: { activo_el: @query.activo_el, dias_vencimiento: @query.dias_vencimiento, cantidad: @query.cantidad,
                                                      producto_id: @query.producto_id })
          else
            @query = ProductosQuery.new activo_el: Time.zone.today, dias_vencimiento: 3, cantidad: 1
            render :index
          end
        end
        format.pdf do
          load_data
          render_pdf silent_print: true if @precio
        end
      end
    end

    private

    def load_data
      @producto = @query.producto_id.present? && Productos::Producto.find(@query.producto_id)
      return unless @producto && @query.cantidad.to_i.positive? && @query.activo_el.present?

      @precio = @producto.buscar_precio(Clientes::Cliente.disponibles_en(tienda_activa).where(nombre: 'Consumidor Final').first,
                                        @query.activo_el)
      @cantidad = @query.cantidad
      @fecha = @query.activo_el
      @dias_vencimiento = @query.dias_vencimiento.to_i
    end
  end
end
