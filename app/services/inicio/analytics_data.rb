module Inicio
  # Builds the heavy data structures needed by the dashboard analytics widgets.
  # All slow queries (12-month comprobantes, churn, cotizaciones, VVC) are
  # computed once and cached in Redis for the day (key includes today's date)
  # so the per-widget AJAX endpoints don't each repeat the same work.
  class AnalyticsData
    def self.fetch(tienda:, local_id:, es_admin_financiero:)
      key = ['inicio_analytics_data_v1', tienda.id, local_id, Time.zone.today.to_s, es_admin_financiero ? 1 : 0].join('/')
      ttl = Time.current.end_of_day - Time.current
      Rails.cache.fetch(key, expires_in: ttl) { new(tienda, local_id, es_admin_financiero).build }
    end

    def initialize(tienda, local_id, es_admin_financiero)
      @tienda = tienda
      @local_id = local_id
      @es_admin_financiero = es_admin_financiero
      @today = Time.zone.today
      @twelve_months_ago = @today - 12.months
    end

    def build
      data = {
        es_admin_financiero: @es_admin_financiero,
        total_pedidos: total_pedidos,
        active_clientes_count: active_clientes_count,
        churn_counts: churn_counts,
        chart_labels: [],
        freq_values: []
      }

      if @es_admin_financiero
        data.merge!(
          total_revenue: total_revenue,
          total_revenue_usd: total_revenue_usd,
          aov_usd: total_pedidos.positive? ? (total_revenue_usd / total_pedidos) : 0,
          chart_values_pesos: [],
          chart_values_usd: [],
          aov_values_pesos: [],
          aov_values_usd: [],
          avg_vvc: avg_vvc.round(2),
          vvc_clientes_count: vvc_clientes_count
        )
      end

      build_chart_series(data)
      data
    end

    private

    def pedidos_scope
      @pedidos_scope ||= begin
        s = Pedidos::Pedido.where(tienda_id: @tienda.id, estado_id: [3, 4]).where.not(fecha: nil)
        s = s.where(local_id: @local_id) if @local_id
        s
      end
    end

    def comprobantes_scope
      @comprobantes_scope ||= begin
        s = Ventas::Facturacion::Comprobante.where(tienda_id: @tienda.id, estado_id: [2, 3])
        s = s.where(local_id: @local_id) if @local_id
        s
      end
    end

    def total_pedidos
      @total_pedidos ||= pedidos_scope.count
    end

    def active_clientes_count
      Clientes::Cliente.disponibles_en(@tienda).active.count
    end

    def cliente_ids
      @cliente_ids ||= Clientes::Cliente.disponibles_en(@tienda).active.pluck(:id)
    end

    def last_order_by_cliente
      @last_order_by_cliente ||= begin
        s = Pedidos::Pedido
            .joins(:cuenta)
            .where(cuentas: { cliente_id: cliente_ids })
            .where(estado_id: [3, 4])
            .where.not(pedidos: { fecha: nil })
        s = s.where(local_id: @local_id) if @local_id
        s.group('cuentas.cliente_id').pluck(Arel.sql('cuentas.cliente_id, MAX(pedidos.fecha)')).to_h
      end
    end

    def churn_counts
      @churn_counts ||= begin
        counts = { 'activo' => 0, 'en_riesgo' => 0, 'inactivo' => 0, 'perdido' => 0, 'sin_pedidos' => 0 }
        cliente_ids.each do |cid|
          last_date = last_order_by_cliente[cid]
          if last_date.nil?
            counts['sin_pedidos'] += 1
          else
            days = (@today - last_date).to_i
            bucket = if days <= 30 then 'activo'
                     elsif days <= 60 then 'en_riesgo'
                     elsif days <= 90 then 'inactivo'
                     else 'perdido'
                     end
            counts[bucket] += 1
          end
        end
        counts
      end
    end

    def daily_net_pesos
      @daily_net_pesos ||= begin
        rows = comprobantes_scope
               .group(Arel.sql('DATE(fecha_emision)'))
               .group(:type)
               .pluck(Arel.sql('DATE(fecha_emision), type, SUM(total)'))
        h = {}
        rows.each do |fecha, type, total|
          h[fecha] ||= 0
          if type == 'Ventas::Facturacion::NotaCredito'
            h[fecha] -= total.to_f
          else
            h[fecha] += total.to_f
          end
        end
        h
      end
    end

    def cotizaciones
      @cotizaciones ||= Cotizaciones::Dolar.pluck(:fecha, :precio_venta).to_h
    end

    def total_revenue
      facturas = comprobantes_scope.where(type: 'Ventas::Facturacion::Factura').sum(:total).to_f
      ncs = comprobantes_scope.where(type: 'Ventas::Facturacion::NotaCredito').sum(:total).to_f
      facturas - ncs
    end

    def total_revenue_usd
      total = 0.0
      last = nil
      daily_net_pesos.keys.sort.each do |fecha|
        c = cotizaciones[fecha] || last
        last = c if c
        total += (c&.positive? ? daily_net_pesos[fecha] / c : 0)
      end
      total
    end

    def build_chart_series(data)
      monthly_orders = pedidos_scope
                       .where(fecha: @twelve_months_ago..)
                       .group(Arel.sql("DATE_FORMAT(fecha, '%Y-%m')"))
                       .pluck(Arel.sql("DATE_FORMAT(fecha, '%Y-%m'), COUNT(*)"))
                       .to_h

      sorted_months =
        if @es_admin_financiero
          monthly_revenue = build_monthly_revenue
          data[:chart_values_pesos] = []
          data[:chart_values_usd] = []
          months = monthly_revenue[:usd].keys.sort
          months.each do |m|
            data[:chart_values_pesos] << monthly_revenue[:pesos][m].round(2)
            data[:chart_values_usd] << monthly_revenue[:usd][m].round(2)
          end
          months
        else
          monthly_orders.keys.sort
        end

      data[:chart_labels] = sorted_months.map { |m| Date.parse("#{m}-01").strftime('%m/%Y') }
      data[:freq_values] = sorted_months.map { |m| monthly_orders[m] || 0 }

      return unless @es_admin_financiero

      data[:aov_values_pesos] = sorted_months.each_with_index.map do |_m, i|
        data[:freq_values][i].positive? ? (data[:chart_values_pesos][i] / data[:freq_values][i]).round(2) : 0
      end
      data[:aov_values_usd] = sorted_months.each_with_index.map do |_m, i|
        data[:freq_values][i].positive? ? (data[:chart_values_usd][i] / data[:freq_values][i]).round(2) : 0
      end
    end

    def build_monthly_revenue
      pesos = {}
      usd = {}
      last = nil
      daily_net_pesos.keys.sort.select { |f| f >= @twelve_months_ago }.each do |fecha|
        m = fecha.strftime('%Y-%m')
        c = cotizaciones[fecha] || last
        last = c if c
        importe = daily_net_pesos[fecha]
        pesos[m] ||= 0
        pesos[m] += importe
        usd[m] ||= 0
        usd[m] += (c&.positive? ? importe / c : 0)
      end
      { pesos: pesos, usd: usd }
    end

    def vvc_revenue
      @vvc_revenue ||= begin
        s = comprobantes_scope.where(fecha_emision: @twelve_months_ago..)
        s.where(type: 'Ventas::Facturacion::Factura').sum(:total).to_f -
          s.where(type: 'Ventas::Facturacion::NotaCredito').sum(:total).to_f
      end
    end

    def vvc_clientes_count
      @vvc_clientes_count ||= begin
        s = Pedidos::Pedido
            .joins(:cuenta)
            .where(cuentas: { cliente_id: cliente_ids })
            .where(estado_id: [3, 4], tienda_id: @tienda.id)
            .where(pedidos: { fecha: @twelve_months_ago.. })
        s = s.where(local_id: @local_id) if @local_id
        s.distinct.count('cuentas.cliente_id')
      end
    end

    def avg_vvc
      vvc_clientes_count.positive? ? (vvc_revenue / vvc_clientes_count) : 0
    end
  end
end
