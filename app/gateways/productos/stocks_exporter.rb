module Productos
  class StocksExporter < ExcelExporter
    def headers
      [
        'ID', 'Producto', 'Código', 'Categoría', 'Cantidad Actual',
        'Cantidad Mínima', 'Cantidad Máxima', 'Estado', 'Activo',
        'Pronóstico Diario', 'Cobertura Estimada (días)', 'Mínimo Recomendado 45 días'
      ]
    end

    def row(stock)
      [
        stock.id,
        stock.producto.nombre,
        stock.producto.codigo,
        categoria_con_stock(stock.producto.categoria),
        stock.cantidad_actual.to_i,
        stock.cantidad_minima.to_i,
        stock.cantidad_maxima&.to_i,
        estado_stock(stock),
        (stock.activo ? 'Si' : 'No'),
        stock.promedio_venta_diaria_90_dias.round(2),
        stock.cobertura_estimada_dias,
        stock.minimo_recomendado_45_dias
      ]
    end

    def search_scope
      Productos::StocksQuery.new(query_params).reorder(nil).order('productos.nombre asc')
    end

    private

    def categoria_con_stock(categoria)
      return '' unless categoria

      estado = categoria.stock_activo ? 'stock activo' : 'stock inactivo'
      "#{categoria.nombre} (#{estado})"
    end

    def estado_stock(stock)
      if stock.sin_stock?
        'Sin Stock'
      elsif stock.stock_critico?
        'Crítico'
      elsif stock.stock_bajo?
        'Bajo'
      else
        'Normal'
      end
    end
  end
end
