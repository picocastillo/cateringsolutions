class StockAlertsMailer < ApplicationMailer
  def daily_report(tienda)
    @tienda = tienda

    # Base scope for active stock-controlled products
    base_scope = Productos::Stock
                 .joins(producto: :categoria)
                 .where(tienda_id: tienda.id)
                 .where(categorias: { stock_activo: true })
                 .where(productos: { discontinued_at: nil })
                 .where(activo: true)
                 .includes(producto: :categoria)

    # Load all problematic stocks in a single query, then partition in Ruby
    problematic_stocks = base_scope
                         .where(
                           'productos_stocks.cantidad_actual <= productos_stocks.cantidad_minima ' \
                           'OR productos_stocks.cantidad_actual = 0'
                         )
                         .order('productos_stocks.cantidad_actual ASC, productos.nombre ASC')
                         .to_a

    @stocks_criticos = problematic_stocks.select(&:stock_critico?)
    @stocks_bajos = problematic_stocks.select { |s| s.stock_bajo? && !s.stock_critico? }
    @stocks_sin_stock = problematic_stocks.select { |s| s.sin_stock? && !s.stock_critico? }

    # Only send email if there are alerts
    return if problematic_stocks.empty?

    @total_alerts = problematic_stocks.size

    mail(
      to: tienda.stock_notifications_email,
      subject: "[#{tienda.nombre}] Alerta de Stock - #{@total_alerts} productos requieren atención"
    )
  end
end
