class ReporteCocinaExporter < ExcelExporter
  def headers
    [
      'Código', 'Producto', 'Categoria', 'Grupo', 'Aceptados', 'Confirmados', 'Cantidad Total', 'Importe Total'
    ]
  end

  def write_sheet(sheet, _objects)
    prods = search_scope
    write_row sheet, ["Reporte Cocina para Fecha: #{query_params[:fecha].to_date}"], @header_format if query_params[:fecha].present?
    write_row sheet, ["Generado el: #{Time.current}"], @header_format
    write_row sheet, ["Clientes: #{@clientes.map(&:nombre).to_sentence}"], @header_format if @clientes.present?
    fot_query = Productos::ProductosSolicitadosQuery.new(query_params).base_query
    write_row sheet, ["Cantidad Total Productos: #{fot_query.sum('productos_solicitados.cantidad')}"], @total_currency
    write_row sheet, []
    if query_params[:venta_mostrador] == 'true'
      write_productos_por_medio_pago(sheet, prods)
    else
      write_row sheet, headers, @header_format
      prods.each do |c|
        write_row sheet, [
          c.producto.codigo, c.nombre_carrito, c.producto.categoria.nombre, c.producto.categoria.grupo,
          c.cantidad_aceptada, c.cantidad_confirmada, c.cantidad_sumada,
          Danconia::Money.new(c.total_sumado)
        ]
      end
      footers.each { |f| write_row sheet, f, @header_format }
    end
  end

  def write_productos_por_medio_pago(sheet, prods)
    medio_labels = Pedidos::MedioPago::TIPOS
    vm_headers = ['Código', 'Producto', 'Categoria', 'Grupo', 'Cantidad Total', 'Importe Total']

    write_row sheet, vm_headers, @header_format
    prods.each do |c|
      write_row sheet, [
        c.producto.codigo, c.nombre_carrito, c.producto.categoria.nombre, c.producto.categoria.grupo,
        c.cantidad_sumada,
        Danconia::Money.new(c.total_sumado)
      ]
    end

    fot_query = Productos::ProductosSolicitadosQuery.new(query_params)
    total_cant = fot_query.base_query.sum('productos_solicitados.cantidad')
    total_imp = fot_query.base_query.sum('productos_solicitados.cantidad * COALESCE(productos_solicitados.precio_con_descuento, productos_solicitados.precio_unitario) * COALESCE(productos_solicitados.peso, 1)')

    write_row sheet, []
    # Medio de pago subtotals
    subtotales = fot_query.subtotales_por_medio_pago
    subtotales.each do |tipo, importe|
      label = medio_labels[tipo] || tipo.to_s.capitalize
      write_row sheet, ['', '', '', label, '', Danconia::Money.new(importe)]
    end

    write_row sheet, ['', '', '', 'Total', total_cant, Danconia::Money.new(total_imp)], @header_format
  end

  def footers
    fot_query = Productos::ProductosSolicitadosQuery.new(query_params).base_query
    [
      [
        '', '', '', 'Aceptados Totales', fot_query.sum('if(pedidos.estado_id = 2, cantidad, 0)'), '', '', ''
      ],
      [
        '', '', '', '', 'Confirmados Totales', fot_query.sum('if(pedidos.estado_id = 3, cantidad, 0)'), '', ''
      ],
      [
        '', '', '', '', '', 'Cantidad Total', fot_query.sum('productos_solicitados.cantidad'), ''
      ],
      [
        '', '', '', '', '', '', 'Importe Total', Danconia::Money.new(fot_query.sum('productos_solicitados.cantidad * COALESCE(productos_solicitados.precio_con_descuento, productos_solicitados.precio_unitario) * COALESCE(productos_solicitados.peso, 1)'))
      ]
    ]
  end

  def search_scope
    @query = Productos::ProductosSolicitadosQuery.new(query_params)
    # Build unique, ordered clients list from matching pedidos
    base = @query.base_query.joins(pedido: { cuenta: :cliente })
    ids = base.distinct.pluck('clientes.id')
    @clientes = Clientes::Cliente.where(id: ids).order('clientes.nombre')
    relation = @query.relation
    relation.sort_by do |x|
      [
        x.producto&.categoria&.grupo.to_s,
        x.producto&.categoria&.codigo.to_s,
        x.producto&.nombre.to_s
      ]
    end
  end
end
