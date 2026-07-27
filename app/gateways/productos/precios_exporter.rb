module Productos
  class PreciosExporter < ExcelExporter
    include FormattingHelper
    include ActionView::Helpers::NumberHelper

    def headers
      [
        'idPrecio', 'Código Producto', 'Códigos Externos', 'Producto', 'Actualizado el', 'Cuits Clientes', 'Clientes', 'Fecha Desde', 'Fecha Hasta', 'Importe'
      ]
    end

    def setup_column_formats
      @column_formats = {
        headers.index('Importe') => @currency_format,
        headers.index('Actualizado el') => @date_format,
        headers.index('Fecha Desde') => @date_format,
        headers.index('Fecha Hasta') => @date_format
      }
    end

    def row(c)
      [
        c.id, c.producto.codigo, c.producto.codigos_externos, c.producto.nombre,
        c.updated_at&.to_date,
        c.clientes.map(&:cuit).join(', '), c.clientes.map(&:nombre).join(', '),
        c.fecha_desde.to_date, c.fecha_hasta.try(&:to_date), c.importe
      ]
    end

    def search_scope
      Productos::ListasPreciosQuery.new(query_params).reorder('').includes(:clientes, producto: :categoria).to_a
    end
  end
end
