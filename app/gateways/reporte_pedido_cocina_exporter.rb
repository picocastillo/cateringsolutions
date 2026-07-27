class ReportePedidoCocinaExporter < ExcelExporter
  def headers
    [
      'Producto', 'Cantidad'
    ]
  end

  def write_sheet(sheet, _objects)
    prods = search_scope
    write_row sheet, ["PEDIDO COCINA N: #{pedido_cocina.codigo}"], @header_format
    fecha = params.dig(:q, :fecha)
    write_row sheet, ["Fecha: #{fecha.to_date}"], @header_format if fecha.present?
    write_row sheet, ["Generado el: #{Time.current}"], @header_format
    write_row sheet, ["Clientes: #{@clientes.map(&:nombre).to_sentence}"], @header_format if @clientes.present?
    write_row sheet, ["Cantidad Total Productos: #{total_cantidad}"], @total_currency
    write_row sheet, []
    write_row sheet, headers, @header_format
    prods.each do |c|
      write_row sheet, [
        c.nombre_carrito,
        c.cantidad_sumada
      ]
    end
    footers.each { |f| write_row sheet, f, @header_format }
  end

  def footers
    [
      ['TOTAL', total_cantidad]
    ]
  end

  def search_scope
    cliente_ids = pedidos_activos.joins(cuenta: :cliente).distinct.pluck('clientes.id')
    @clientes = Clientes::Cliente.where(id: cliente_ids).order(:nombre)

    productos_agrupados.sort_by do |x|
      [
        x.producto&.categoria&.grupo.to_s,
        x.producto&.categoria&.codigo.to_s,
        x.producto&.nombre.to_s
      ]
    end
  end

  private

  def pedido_cocina
    if pedido_cocina_id.blank?
      Rails.logger.error "[ReportePedidoCocinaExporter] ID nil. params=#{params.inspect} proceso_id=#{id}"
      raise ActiveRecord::RecordNotFound, "No se especificó el ID del pedido de cocina (params: #{params.keys})"
    end

    @pedido_cocina ||= Pedidos::PedidoCocina.find(pedido_cocina_id)
  end

  def pedido_cocina_id
    p = params.with_indifferent_access
    p[:pedido_cocina_id] || p[:id] || p.dig(:q, :pedido_cocina_id)
  end

  def pedidos_activos
    pedido_cocina.pedidos.where.not(estado_id: [1, 5])
  end

  def productos_agrupados
    Productos::ProductoSolicitado
      .where(pedido_id: pedidos_activos.select(:id))
      .group(:producto_id)
      .select('productos_solicitados.*, sum(cantidad) as cantidad_sumada')
  end

  def total_cantidad
    @total_cantidad ||= Productos::ProductoSolicitado
                        .where(pedido_id: pedidos_activos.select(:id))
                        .sum(:cantidad)
  end
end
