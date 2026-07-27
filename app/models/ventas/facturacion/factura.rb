module Ventas
  module Facturacion
    class Factura < Comprobante
      def factura?
        true
      end

      def rol_asociado
        :facturar
      end

      MEDIOS_POR_TIPO = {
        'efectivo' => { clase: Logistica::Flujos::Efectivo, assoc: :efectivos },
        'debito' => { clase: Logistica::Flujos::Debito, assoc: :debitos },
        'credito' => { clase: Logistica::Flujos::Credito, assoc: :creditos },
        'qr' => { clase: Logistica::Flujos::Qr, assoc: :qrs },
        'transferencia' => { clase: Logistica::Flujos::Transferencia, assoc: :transferencias }
      }.freeze

      def cobrar_e_imputar(u)
        if medio_de_pago.present?
          m = Logistica::Flujos::MercadoPago.new(importe: saldo, pago_electronico: medio_de_pago)
          recibo = Cobros::Recibo.create autor: u, cuenta: cuenta, tienda: tienda, mercado_pagos: [m]
        elsif pedido&.medios_pago&.any?
          # Multiple medios de pago from pedido
          medios_hash = Hash.new { |h, k| h[k] = [] }
          pedido.medios_pago.each do |mp|
            config = MEDIOS_POR_TIPO[mp.tipo] || MEDIOS_POR_TIPO['efectivo']
            medios_hash[config[:assoc]] << config[:clase].new(importe: mp.importe)
          end
          recibo = Cobros::Recibo.create(medios_hash.merge(autor: u, cuenta: cuenta, tienda: tienda))
        else
          # Backward compat: single medio_pago_tipo
          tipo = pedido&.medio_pago_tipo.presence || 'efectivo'
          config = MEDIOS_POR_TIPO[tipo] || MEDIOS_POR_TIPO['efectivo']
          m = config[:clase].new(importe: saldo)
          recibo = Cobros::Recibo.create autor: u, cuenta: cuenta, tienda: tienda, config[:assoc] => [m]
        end

        recibo.afectaciones.build afectado: self, importe: saldo
        recibo.save!
        recibo.confirmar!(u)
      end

      private

      def asignar_tipo
        return unless new_record?

        self.tipo = Comprobantes::Tipo.find_by(codigo: 1)
      end
    end
  end
end
