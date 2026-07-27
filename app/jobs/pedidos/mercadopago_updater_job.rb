module Pedidos
  class MercadopagoUpdaterJob < ApplicationJob
    require 'mercadopago'
    queue_as :fast

    STATES = {
      complete: ['approved'],
      failure: ['rejected'],
      void: ['refunded', 'cancelled', 'charged_back'],
      pending: ['pending', 'in_process', 'in_mediation']
    }.freeze

    def perform(payment_id)
      mp = Mercadopago::SDK.new(Rails.application.secrets.mp)
      payment_response = mp.payment.get(payment_id)[:response]
      return if payment_response.blank?

      Rails.logger.info "Respuesta de Mercadopago: #{payment_response}"
      er = payment_response['external_reference']
      Rails.logger.info "MercadopagoUpdaterJob: External Reference: #{er}"
      return if er.blank?

      # Multi-pedido payment: external_reference = "multiple-{grupo_id}-{uid}"
      if er.start_with?('multiple-')
        handle_multiple_payment(er, payment_response)
        return
      end

      pid = er.split('-')[0]
      Rails.logger.info "MercadopagoUpdaterJob: Extracted PID: #{pid}"
      uid = er.split('-')[1]
      Rails.logger.info "MercadopagoUpdaterJob: Extracted UID: #{uid}"

      if pid.present? && (pedido = Pedidos::Pedido.find_by(id: pid.to_i))
        # Validate user permissions
        unless uid.present? && [pedido.autor_id, pedido.usuario_id].include?(uid.to_i)
          Rails.logger.warn "MercadopagoUpdaterJob: User #{uid} not authorized for pedido #{pedido.id}"
          return
        end

        payment_status = payment_response['status']
        Rails.logger.info "MercadopagoUpdaterJob: Processing payment status: #{payment_status} for pedido: #{pedido.id}"

        if STATES[:complete].include?(payment_status)
          pedido.imputar_pago(payment_response)
        elsif STATES[:failure].include?(payment_status) || STATES[:void].include?(payment_status)
          pedido.desimputar_pago(payment_response)
          pedido.cancelar! if pedido.estado_id != 5 # 5 is the ID for 'cancelled' state
        elsif STATES[:pending].include?(payment_status)
          Rails.logger.info 'MercadopagoUpdaterJob: Payment pending, no action taken'
          # No action for pending payments
        else
          Rails.logger.warn "MercadopagoUpdaterJob: Unknown payment status: #{payment_status}"
        end
      else
        Rails.logger.warn "MercadopagoUpdaterJob: Pedido not found with PID: #{pid}"
      end
    end

    private

    def handle_multiple_payment(ext_ref, payment_response)
      parts = ext_ref.split('-')
      grupo_id = parts[1]
      parts[2]

      grupo = Pedidos::PedidoMultiple.find_by(id: grupo_id.to_i)
      unless grupo
        Rails.logger.warn "MercadopagoUpdaterJob: PedidoMultiple not found: #{grupo_id}"
        return
      end

      payment_status = payment_response['status']
      Rails.logger.info "MercadopagoUpdaterJob: Multi-pedido #{grupo.id} payment status: #{payment_status}"

      if STATES[:complete].include?(payment_status)
        # SECURITY (Bug C — incident 2026-05-17 PM 78, MP 159008984833 $14,820):
        # 1. Do NOT mark the grupo as :pagado before the children are imputed —
        #    if the loop crashes partway through (or every pedido raises), we
        #    must not leave the grupo flagged paid with no PagoElectronico rows.
        # 2. Rescue StandardError (not just RecordInvalid) so unrelated bugs
        #    (NoMethodError, ActiveRecord::StatementInvalid, etc.) inside
        #    imputar_pago do not abort the whole job and leak money.
        # 3. Notify so the next missing payment is detected in seconds, not days.
        successful = 0
        failures = []
        grupo.pedidos.each do |p|
          next if p.cancelado? || p.productos_solicitados.empty?

          begin
            p.imputar_pago(payment_response)
            successful += 1
          rescue StandardError => e
            failures << [p.id, e]
            Rails.logger.error "MercadopagoUpdaterJob: imputar_pago failed for pedido #{p.id} in grupo #{grupo.id}: " \
                               "#{e.class}: #{e.message}\n#{e.backtrace&.first(15)&.join("\n")}"
            begin
              ExceptionNotifier.notify_exception(
                e,
                data: { payment_id: payment_response['id'], grupo_id: grupo.id, pedido_id: p.id, external_reference: ext_ref }
              )
            rescue StandardError
              # Notifier failures must never swallow the original error path
            end
          end
        end

        # Only flip the grupo to :pagado if every eligible child was imputed.
        raise failures.first.last unless failures.empty?

        grupo.update!(estado: Pedidos::PedidoMultiple::ESTADOS[:pagado])

      # Re-raise the first failure so DelayedJob retries the webhook; the
      # successful pedidos are idempotent (imputar_pago skips if
      # cobrado/confirmado already), and re-raising the original error
      # preserves the backtrace for debugging.

      elsif STATES[:failure].include?(payment_status) || STATES[:void].include?(payment_status)
        grupo.update!(estado: Pedidos::PedidoMultiple::ESTADOS[:abierto])
        grupo.pedidos.each do |p|
          p.desimputar_pago(payment_response)
        end
      elsif STATES[:pending].include?(payment_status)
        Rails.logger.info 'MercadopagoUpdaterJob: Multi-pedido payment pending, no action taken'
      else
        Rails.logger.warn "MercadopagoUpdaterJob: Unknown payment status for multi-pedido: #{payment_status}"
      end
    end
  end
end
