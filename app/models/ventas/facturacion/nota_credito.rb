module Ventas
  module Facturacion
    class NotaCredito < Comprobante
      before_validation :cachear_pedido
      validate :no_excede_total_factura

      def nota_credito?
        true
      end

      def nota?
        true
      end

      def rol_asociado
        :generar_notas_credito
      end

      def self.generar_nc_seguros(factura, cbtes_anteriores = [])
        renglones_nc = factura.renglones.map(&:dup)
        imputada = (cbtes_anteriores + [factura]).reverse.detect(&:factura?)
        new.preparar_para_cancelar_a imputada, renglones_nc, imputada
      end

      def self.generar_nc_pedido(factura, cbtes_anteriores = [])
        renglones_nc = factura.renglones.map(&:dup)
        imputada = (cbtes_anteriores + [factura]).reverse.detect(&:factura?)
        new.preparar_para_cancelar_a imputada, renglones_nc, imputada
      end

      def anular!(u); end

      def self.generar_si_corresponde(factura, cbtes_anteriores = [])
        return [factura] if factura.empty?

        renglones_nc, factura.renglones = factura.renglones.partition { |r| r.precio_unitario.negative? }
        renglones_nc.each { |r| r.precio_unitario = -r.precio_unitario }
        nc_provisoria = new renglones: renglones_nc
        imputada = (cbtes_anteriores + [factura]).reverse.detect do |c|
          c.factura? && c.total_sin_iva >= nc_provisoria.total_sin_iva
        end
        nc_definitiva = new.preparar_para_cancelar_a imputada, renglones_nc, imputada || factura
        [factura, nc_definitiva].reject(&:empty?)
      end

      def generar_afectaciones
        rs_con_cbte_afectado = renglones_con_cbtes_afectados
        if rs_con_cbte_afectado.any?
          rs_con_cbte_afectado.group_by(&:comprobante_afectado).each do |f, rs|
            afectaciones.build afectado: f, importe: rs.map(&:total_con_iva).sum
          end
        elsif afectaciones.size == 1
          afectaciones[0].importe = total
        end
        self
      end

      private

      def asignar_tipo
        return unless new_record?

        self.tipo = Comprobantes::Tipo.find_by(codigo: 3)
      end

      def renglones_con_cbtes_afectados
        if renglones.any?(&:comprobante_afectado)
          renglones
        else
          []
        end
      end

      def cachear_pedido
        self.pedido = cancela_a.pedido if cancela_a
      end

      # Bug D: cumulative confirmed/finalizado NCs against a factura must
      # never exceed that factura's total. Partial NCs are fine; the sum is
      # what matters.
      def no_excede_total_factura
        factura = cancela_a
        return unless factura

        nuevo_total = total.to_f.abs
        return if nuevo_total.zero?

        ya = already_credited_against_cancela_a.to_f
        return if nuevo_total + ya <= factura.total.to_f + 0.01

        errors.add :base,
                   "El total de notas de crédito ($#{format('%.2f', nuevo_total + ya)}) excede el total de la factura ($#{format('%.2f', factura.total.to_f)})"
      end

      def already_credited_against_cancela_a
        factura = cancela_a
        return 0.0 unless factura&.persisted?

        scope = self.class
                    .joins(:afectaciones)
                    .where(afectaciones: { afectado_id: factura.id })
                    .where(estado_id: Comprobantes::Estado[:confirmado].id)
        scope = scope.where.not(id: id) if persisted?
        scope.to_a.sum { |nc| nc.total.to_f.abs }
      end
    end
  end
end
