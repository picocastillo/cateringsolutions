module Contabilidad
  class CuentasCorrientesExporter < ExcelExporter
    def headers
      ['Cliente', 'Cuenta', 'Usuario', 'Fecha', 'Pedido', 'Comprobante', 'Estado Cobro', 'Vencimiento', 'Cancela_a',
       'Debe', 'Haber', 'Saldo']
    end

    def row(mov)
      pedido_usuario = mov.comprobante.pedido ? mov.comprobante.pedido.usuario.nombre : ''
      [mov.cuenta.cliente, mov.cuenta.to_s, pedido_usuario,
       mov.comprobante.fecha_emision.to_date, mov.comprobante.try(&:pedido), mov.comprobante,
       mov.estado, mov.vencimiento, mov.imputado, mov.debe, mov.haber, mov.saldo_cuenta]
    end

    def search_scope
      RenglonesMovimientosQuery.new(query_params)
    end

    def setup_column_formats
      @column_formats = {
        headers.index('Debe') => @currency_format,
        headers.index('Haber') => @currency_format,
        headers.index('Saldo') => @currency_format
      }
    end

    private

    def enumerable(objects)
      MovsConSaldo.new objects
    end

    class MovsConSaldo
      include Enumerable

      def initialize(objects)
        @objects = objects
      end

      def each(&)
        @objects.page(1).per_page(500).total_pages.times do |x|
          @objects.movimientos_con_saldos(x + 1, 500).each(&)
        end
      end
    end
  end
end
