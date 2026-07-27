class ReporteDespachoExporter < ExcelExporter
  include FormattingHelper
  include ActionView::Helpers::NumberHelper

  def headers
    (@query.agrupar_por_id > 1 ? ['Cuenta'] : []) +
      (@query.agrupar_por_id > 1 ? ['Usuario'] : []) +
      ['Enviar a', 'Producto', 'Cantidad']
  end

  def write_sheet(sheet, _objects)
    despachos_by_cuenta = @despachos.group_by { |ps| ps.pedido.cuenta_id }
    @query.clientes_lista.includes(:cuentas).find_each do |cl|
      cuenta_ids = cl.cuentas.map(&:id)
      prods = cuenta_ids.flat_map { |cid| despachos_by_cuenta[cid] || [] }
      next unless prods.any?

      if query_params[:fecha_desde].present?
        fecha_header = if query_params[:fecha_hasta].present? && query_params[:fecha_hasta] != query_params[:fecha_desde]
                         "Reporte Despacho desde #{query_params[:fecha_desde].to_date} hasta #{query_params[:fecha_hasta].to_date}"
                       else
                         "Reporte Despacho para Fecha: #{query_params[:fecha_desde].to_date}"
                       end
        write_row sheet, [fecha_header], @header_format
        write_row sheet, []
      end
      write_row sheet, ['Cliente:', cl.nombre.upcase], @header_format
      ctas = if @query.cuentas_ids.present?
               cl.cuentas.select do |x|
                 @query.cuentas_ids.split(',').map(&:to_i).include?(x.id)
               end.sort_by(&:nombre).map(&:nombre).join(', ')
             else
               'Todas'
             end
      write_row sheet, ['Cuentas:', ctas], @header_format
      write_row sheet, ['Cantidad Total Productos:', prods.sum { |x| x.cantidad_sumada.to_i }], @header_format
      write_row sheet, []
      write_row sheet, headers, @header_format
      prods.sort_by do |x|
        [x.pedido.direccion_envio.presence || '', x.pedido.cuenta.nombre, (x.pedido.usuario ? x.pedido.usuario.nombre : ''),
         x.producto.categoria.codigo, x.producto.nombre]
      end.each do |c|
        write_row sheet, ((@query.agrupar_por_id > 1 ? [c.pedido.cuenta.nombre] : []) + (@query.agrupar_por_id > 1 ? [c.pedido.usuario.try(:nombre)] : []) + [
          c.pedido.enviar_a_string, c.nombre_carrito, c.cantidad_sumada
        ])
      end
      write_row sheet, []
      write_row sheet, []
      write_row sheet, []
    end
  end

  def search_scope
    @query = Productos::ProductosSolicitadosQuery.new query_params.merge(estado_id: 3)
    @despachos = @query.crear_grupos(@query.relation)
                       .includes(:menu_diario, pedido: [{ cuenta: :cliente }, :usuario], producto: [:categoria])
                       .to_a
  end
end
