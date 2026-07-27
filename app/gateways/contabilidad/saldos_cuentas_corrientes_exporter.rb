module Contabilidad
  class SaldosCuentasCorrientesExporter < ExcelExporter
    def headers
      ['Cliente'] +
        (@query.visualizar_por_id > 1 ? ['Cuenta'] : []) +
        (@query.visualizar_por_id > 2 ? ['Usuario'] : []) +
        ['Saldo Total'] +
        search_scope.headers_de_vencimiento.map { |_rango, header| header } +
        ['Saldo Favor']
    end

    def row(mov)
      usuario_col = if @query.visualizar_por_id > 2
                      [(mov.comprobante.pedido ? mov.comprobante.pedido.usuario.nombre : '')]
                    else
                      []
                    end
      [mov.cuenta.cliente.nombre] +
        (@query.visualizar_por_id > 1 ? [mov.comprobante.pedido.cuenta.nombre] : []) +
        usuario_col +
        [mov.saldo_total] +
        search_scope.headers_de_vencimiento.map { |rango, _header| mov.send(rango.to_sym) } +
        [mov.saldo_favor]
    end

    def footers
      [['Total'] +
        (@query.visualizar_por_id > 1 ? [''] : []) +
        (@query.visualizar_por_id > 2 ? [''] : []) +
        [search_scope.totales.saldo_total] +
        search_scope.headers_de_vencimiento.map { |rango, _header| search_scope.totales.send(rango.to_sym) } +
        [search_scope.totales.saldo_favor]]
    end

    def setup_column_formats
      @column_formats = {
        headers.index('Saldo Favor') => @currency_format,
        headers.index('Saldo Total') => @currency_format
      }
      search_scope.headers_de_vencimiento.each_value do |header|
        @column_formats[headers.index(header)] = @currency_format
      end
    end

    def search_scope
      @query = SaldosMovimientosQuery.new query_params
    end
  end
end
