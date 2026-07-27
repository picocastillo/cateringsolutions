module Pedidos
  class ResumenPedidosExporter < ExcelExporter
    def run(objects)
      preparar_adjunto filename

      # Materialize both datasets upfront. The GROUP BY query scans 100K+ source rows;
      # batching with OFFSET would re-execute that full scan per batch (115+ times for sheet 2).
      # Single .to_a fires one query each: ~4s total vs ~165s batched.
      sheet1_data = objects.to_a
      sheet2_data = objects.group('pedidos.fecha').to_a
      progreso.start(sheet1_data.size + sheet2_data.size)

      @current_row = 0
      @workbook = WriteXLSX.new(xlsx_filepath, optimization: true)
      setup_formats

      sheet = @workbook.add_worksheet('Por Mes')
      write_sheet sheet, sheet1_data

      @with_date = true
      @current_row = 0
      setup_column_formats

      sheet2 = @workbook.add_worksheet('Por Día')
      write_sheet sheet2, sheet2_data

      @workbook.close
    end

    def headers
      [
        'DNI', 'Cuit', 'Legajo', 'Cliente', 'Cuenta', 'Nombre Usuario', 'Cantidad Productos', 'Importe Total'
      ] + (@with_date ? ['Fecha'] : [])
    end

    def row(c)
      [
        c.pedido.usuario.try(&:dni), c.pedido.usuario.try(&:cuit),
        c.pedido.usuario.try(&:legajo), c.pedido.cuenta.cliente,
        c.pedido.cuenta, c.pedido.usuario.try(&:nombre),
        c.cantidad_sumada, c.total_sumado
      ] + (@with_date ? [c.pedido.fecha] : [])
    end

    def setup_column_formats
      @column_formats = { headers.index('Importe Total') => @currency_format }
    end

    def footers
      fot_query = Productos::ProductosSolicitadosQuery.new(query_params).base_query
      importe_sum = fot_query.sum(
        'productos_solicitados.cantidad * COALESCE(productos_solicitados.precio_con_descuento, productos_solicitados.precio_unitario) * COALESCE(productos_solicitados.peso, 1)'
      )
      [
        [
          '', '', '', '', '', 'Cantidad Total',
          fot_query.sum('productos_solicitados.cantidad'), ''
        ],
        [
          '', '', '', '', '', '', 'Importe Total', importe_sum
        ]
      ]
    end

    def search_scope
      join_sql = 'join pedidos on pedidos.id=productos_solicitados.pedido_id ' \
                 'left join usuarios on usuarios.id=pedidos.usuario_id'
      Productos::ProductosSolicitadosQuery.new(query_params)
                                          .base_query
                                          .joins(join_sql)
                                          .includes(pedido: [:usuario, :cuenta])
                                          .group('pedidos.cuenta_id, pedidos.usuario_id')
                                          .order('usuarios.nombre asc')
                                          .select(
                                            'productos_solicitados.*, ' \
                                            'sum(COALESCE(precio_con_descuento, productos_solicitados.precio_unitario) * cantidad * COALESCE(productos_solicitados.peso, 1)) total_sumado, ' \
                                            'sum(cantidad) cantidad_sumada'
                                          )
    end
  end
end
