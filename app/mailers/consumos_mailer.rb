class ConsumosMailer < ApplicationMailer
  def reporte_mensual(cliente, destinatario_email)
    @cliente = cliente
    @tienda = cliente.tienda

    @fecha_fin = 1.month.ago.end_of_month.to_date
    @fecha_inicio = @fecha_fin.beginning_of_month

    @mes = I18n.l(@fecha_inicio, format: '%B %Y').capitalize
    @dias_del_mes = @fecha_fin.day

    # Daily totals for the current month
    @totales_diarios = Pedidos::Pedido
                       .joins(:cuenta)
                       .where(cuentas: { cliente_id: cliente.id })
                       .where(fecha: @fecha_inicio..@fecha_fin)
                       .where.not(estado_id: 5) # exclude cancelled
                       .joins(:productos_solicitados)
                       .group('pedidos.fecha')
                       .sum('productos_solicitados.cantidad * COALESCE(productos_solicitados.precio_con_descuento, productos_solicitados.precio_unitario) * COALESCE(productos_solicitados.peso, 1)')
                       .transform_keys(&:to_date)

    @total_mes = @totales_diarios.values.sum

    # Pedido count per day
    @pedidos_por_dia = Pedidos::Pedido
                       .joins(:cuenta)
                       .where(cuentas: { cliente_id: cliente.id })
                       .where(fecha: @fecha_inicio..@fecha_fin)
                       .where.not(estado_id: 5)
                       .group('pedidos.fecha')
                       .count
                       .transform_keys(&:to_date)

    # Distinct users per day
    @usuarios_por_dia = Pedidos::Pedido
                        .joins(:cuenta)
                        .where(cuentas: { cliente_id: cliente.id })
                        .where(fecha: @fecha_inicio..@fecha_fin)
                        .where.not(estado_id: 5)
                        .group('pedidos.fecha')
                        .distinct.count('pedidos.usuario_id')
                        .transform_keys(&:to_date)

    # Count distinct (usuario, fecha) pairs — each user gets one daily limit per day they ordered
    @usuario_dias = Pedidos::Pedido
                    .joins(:cuenta)
                    .where(cuentas: { cliente_id: cliente.id })
                    .where(fecha: @fecha_inicio..@fecha_fin)
                    .where.not(estado_id: 5)
                    .distinct.count('CONCAT(pedidos.usuario_id, "-", pedidos.fecha)')

    # Limit comparisons: limit × distinct user-days
    @limite_pesos = cliente.limite_compra_pesos
    @limite_dolares = cliente.limite_compra_dolares

    @limite_mensual_pesos = @limite_pesos * @usuario_dias if @limite_pesos.present?

    if @limite_dolares.present?
      # Use daily dollar rates for accurate limit calculation
      # Each day's limit = users_that_day × limit_usd × rate_that_day
      dias_con_pedidos = @usuarios_por_dia.keys
      @cotizaciones_diarias = dias_con_pedidos.index_with do |dia|
        Cotizaciones::Dolar.precio_para_fecha(dia)
      end

      @limite_mensual_dolares_en_pesos = @usuarios_por_dia.sum do |dia, n_usuarios|
        rate = @cotizaciones_diarias[dia]
        rate&.positive? ? n_usuarios * @limite_dolares * rate : 0
      end

      # Weighted average rate (weighted by users per day) for display
      total_usuarios = @usuarios_por_dia.values.sum
      if total_usuarios.positive? && @limite_mensual_dolares_en_pesos.positive?
        @precio_dolar_promedio = @limite_mensual_dolares_en_pesos / (@limite_dolares * total_usuarios)
      end

      @limite_mensual_dolares_en_pesos = nil unless @limite_mensual_dolares_en_pesos&.positive?
    end

    mail(
      to: destinatario_email,
      subject: "[#{@tienda.nombre}] Consumos del mes - #{@cliente.nombre} - #{@mes}"
    )
  end
end
