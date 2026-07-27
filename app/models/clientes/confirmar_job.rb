module Clientes
  class ConfirmarJob < ApplicationJob
    queue_as :confirmacion

    # MariaDB GET_LOCK name. Scoped per-pedido so concurrent workers never
    # process the same pedido, but different pedidos run in parallel.
    def self.advisory_lock_name(pedido_id)
      "kiosk:confirmar_pedido:#{pedido_id}"
    end

    def perform(pedido_id)
      with_advisory_lock(pedido_id) do |acquired|
        # Another worker (or a re-enqueue from the cron) is already handling
        # this pedido — drop silently. The cron runs every 5 minutes, so the
        # work will be picked up again if needed.
        return unless acquired

        ped = Pedidos::Pedido.find(pedido_id)

        # Skip if already confirmed or cancelled — no lock needed for this read
        return if ped.confirmado? || ped.cancelado?

        if ped.productos_solicitados.present?
          # confirmar! uses with_lock internally to prevent race conditions
          ped.confirmar!
        else
          Rails.logger.error "Eliminando pedido #{ped} por no tener productos asignados. Usuario: #{ped.usuario}"
          ped.destroy!
        end
      end
    end

    private

    def with_advisory_lock(pedido_id)
      conn = ActiveRecord::Base.connection
      name = self.class.advisory_lock_name(pedido_id)
      quoted = conn.quote(name)
      acquired = false
      # GET_LOCK(name, 0) -> 1 acquired, 0 timeout, NULL on error.
      # Released explicitly in ensure so we don't depend on connection recycling.
      acquired = conn.select_value("SELECT GET_LOCK(#{quoted}, 0)").to_i == 1
      yield acquired
    ensure
      conn.select_value("SELECT RELEASE_LOCK(#{quoted})") if acquired
    end
  end
end
