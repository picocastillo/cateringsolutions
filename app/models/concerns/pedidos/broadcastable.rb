module Pedidos
  module Broadcastable
    extend ActiveSupport::Concern

    private

    def broadcast_daily_orders_update
      return if fecha.to_date != Date.current

      # If record is not persisted (destroyed), broadcast immediately
      unless persisted?
        perform_broadcast
        return
      end

      # Use Redis service client for global throttling across all server instances
      throttle_key = "daily_orders_broadcast_#{tienda_id}"

      # Check if we've broadcast recently (within 3 seconds)
      if RedisServiceClient.throttled?(throttle_key)
        # Schedule a delayed broadcast instead
        schedule_delayed_broadcast
        return
      end

      # Set Redis throttle with 3 second expiration
      RedisServiceClient.setex(throttle_key, 3, Time.current.to_i)
      # Perform the actual broadcast
      perform_broadcast
    end

    def schedule_delayed_broadcast
      # Schedule a broadcast for 3 seconds from now
      # This ensures we get the latest data after the throttle period
      delay_key = "daily_orders_delayed_#{tienda_id}"
      job_id_key = "daily_orders_job_id_#{tienda_id}"

      # Cancel any existing delayed job for this tienda
      existing_job_id = RedisServiceClient.get(job_id_key)
      if existing_job_id
        begin
          Delayed::Job.find(existing_job_id).destroy
        rescue ActiveRecord::RecordNotFound
          Rails.logger.warn "\e[33m⚠️ [DELAYED] Previous job not found (already executed or cancelled)\e[0m"
        end
      end

      # Schedule new delayed job
      job = delay(run_at: 3.seconds.from_now, queue: 'fast').perform_delayed_broadcast

      # Store the new job ID and delay flag
      RedisServiceClient.setex(delay_key, 15, Time.current.to_i) # Slightly longer than delay
      RedisServiceClient.setex(job_id_key, 15, job.id)
    end

    def perform_delayed_broadcast
      # Clear the delay flags
      delay_key = "daily_orders_delayed_#{tienda_id}"
      job_id_key = "daily_orders_job_id_#{tienda_id}"

      RedisServiceClient.del(delay_key)
      RedisServiceClient.del(job_id_key)
      # Perform the broadcast with fresh data
      perform_broadcast
    end

    def perform_broadcast
      # Broadcast to all users of this tienda
      day = Time.zone.today
      # day = 33.days.ago.to_date
      base = Pedidos::Pedido.where(tienda: tienda_id, fecha: day)

      # Calculate counters
      total_pedidos_hoy = base.where.not(estado_id: [1, 4, 5]).count
      pedidos_pendientes = base.where(estado_id: 2, pedido_cocina_id: nil).count
      pedidos_listos_cocinar = base.where(estado_id: 3, pedido_cocina_id: nil).count
      pedidos_cocinados = base.where(estado_id: 3).where.not(pedido_cocina_id: nil).count

      # Effective hora_corte for pending pedidos (cuenta override > cliente fallback)
      pedidos_pendientes_cortes = base.where.not(estado_id: [1, 4, 5])
                                      .joins(cuenta: :cliente)
                                      .distinct
                                      .pluck(Arel.sql("COALESCE(NULLIF(cuentas.horario_corte_pedidos, ''), clientes.horario_corte_pedidos)"))
                                      .compact_blank.uniq.sort

      channel_name = "daily_orders_#{tienda_id}"
      ActionCable.server.broadcast(
        channel_name,
        {
          type: 'daily_orders_update',
          counters: {
            total_pedidos_hoy: total_pedidos_hoy,
            pedidos_pendientes: pedidos_pendientes,
            pedidos_listos_cocinar: pedidos_listos_cocinar,
            pedidos_cocinados: pedidos_cocinados,
            pedidos_pendientes_cortes: pedidos_pendientes_cortes
          }
        }
      )
    end
  end
end
