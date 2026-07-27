class DailyOrdersChannel < ApplicationCable::Channel
  def subscribed
    logger.info 'DailyOrdersChannel: Attempting to subscribe'
    logger.info "DailyOrdersChannel: current_user = #{current_user.inspect}"
    logger.info "DailyOrdersChannel: current_user.tienda_activa = #{current_user&.tienda_activa&.inspect}"

    if current_user&.tienda_activa
      stream_from "daily_orders_#{current_user.tienda_activa.id}"
      logger.info "DailyOrdersChannel: Subscribed to daily_orders_#{current_user.tienda_activa.id}"
    elsif Rails.env.production?
      # In production, reject unauthorized connections
      logger.warn 'DailyOrdersChannel: Rejecting unauthorized connection in production'
      reject
    else
      logger.warn 'DailyOrdersChannel: NOT Subscribed - no user or tienda_activa'
    end
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
  end
end
