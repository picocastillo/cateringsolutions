class InicioController < ApplicationController
  def index
    authorize! :index, :inicio
    @query = Productos::ProductosSolicitadosQuery.new query_params.merge(fecha_obligatoria: true).reverse_merge(
      fecha_desde: Time.zone.today, fecha_hasta: Time.zone.today
    )
    if @query.valid?
      respond_to do |format|
        format.any :html, :js do
          vm_filter = query_params[:venta_mostrador]

          if tienda_activa&.carrito_de_compras && vm_filter != 'true'
            @query_cocina = Productos::ProductosSolicitadosQuery.new(
              query_params.merge(fecha_obligatoria: true, venta_mostrador: 'false').reverse_merge(
                fecha_desde: Time.zone.today, fecha_hasta: Time.zone.today
              )
            )
            @productos_cocina = @query_cocina.relation.includes(:producto)
          end

          if tienda_activa&.venta_mostrador? && vm_filter != 'false'
            @query_vm = Productos::ProductosSolicitadosQuery.new(
              query_params.merge(fecha_obligatoria: true, venta_mostrador: 'true').reverse_merge(
                fecha_desde: Time.zone.today, fecha_hasta: Time.zone.today
              )
            )
            @productos_vm = @query_vm.relation.includes(:producto)
            @subtotales_medios_pago = @query_vm.subtotales_por_medio_pago
          end

          @link_cocina = true
          load_stock_alerts if current_user.admin? && tienda_activa.present?
          load_precios_alerts if current_user.admin? && tienda_activa.present?
        end
        format.xls do
          export_in_background ReporteCocinaExporter
        end
      end
    else
      vm_filter = query_params[:venta_mostrador]
      if tienda_activa&.carrito_de_compras && vm_filter != 'true'
        @query_cocina = @query
        @productos_cocina = Productos::ProductoSolicitado.where(id: -1)
      end
      if tienda_activa&.venta_mostrador? && vm_filter != 'false'
        @query_vm = @query
        @productos_vm = Productos::ProductoSolicitado.where(id: -1)
      end
      flash.now[:error] = @query.errors
    end
  end

  def ayuda
    authorize! :create, Pedidos::Pedido
  end

  def qz_certificate
    authorize! :create, Pedidos::Pedido
    cert_path = Rails.root.join('config/qz_tray/digital-certificate.txt')
    if File.exist?(cert_path)
      render plain: File.read(cert_path), content_type: 'text/plain'
    else
      head :not_found
    end
  end

  def qz_sign
    authorize! :create, Pedidos::Pedido
    key_path = Rails.root.join('config/qz_tray/private-key.pem')
    unless File.exist?(key_path)
      head :not_found
      return
    end

    request_to_sign = params[:request].to_s
    key = OpenSSL::PKey::RSA.new(File.read(key_path))
    signed = key.sign(OpenSSL::Digest.new('SHA512'), request_to_sign)
    render plain: Base64.strict_encode64(signed), content_type: 'text/plain'
  end

  def test_print
    authorize! :create, Pedidos::Pedido
    head(:forbidden) and return if current_user.cliente?

    respond_to do |format|
      format.pdf { render_pdf }
    end
  end

  def error
    authorize! :index, Clientes::Cliente
  end

  def stats
    authorize! :index, :inicio
    respond_to do |format|
      format.js
    end
  end

  def analytics
    authorize! :index, :inicio
    head :forbidden and return unless current_user.admin?

    respond_to do |format|
      format.js
    end
  end

  def stats_admin
    authorize! :index, :inicio
    head :forbidden and return unless current_user.admin_financiero?

    respond_to do |format|
      format.js
    end
  end

  # Single endpoint that renders one dashboard widget at a time. Each chart and
  # KPI tile in the inicio index lazy-loads via this action so the page does
  # not have to wait for one giant aggregated response. See
  # app/views/inicio/index.html.erb for the JS that drives the calls.
  WIDGETS = {
    # Analytics (admin only). The :financiero key marks widgets that also
    # require admin_financiero? for currency-sensitive data.
    'analytics_kpis_main' => { admin: true, financiero: true },
    'analytics_kpis_pedidos' => { admin: true },
    'analytics_kpis_clientes' => { admin: true },
    'analytics_kpis_churn' => { admin: true },
    'analytics_revenue_chart' => { admin: true, financiero: true },
    'analytics_orders_chart' => { admin: true },
    'analytics_aov_chart' => { admin: true, financiero: true },
    'analytics_churn_chart' => { admin: true },
    'analytics_cac_chart' => { admin: true, financiero: true },
    # Stats (everyone with inicio access)
    'stats_top_productos' => {},
    'stats_top_menus_diarios' => {},
    'stats_usuarios_chart' => {},
    # Stats admin (financiero only)
    'stats_admin_importes_chart' => { admin: true, financiero: true }
  }.freeze

  def widget
    authorize! :index, :inicio
    name = params[:name].to_s
    cfg = WIDGETS[name]
    return head :not_found unless cfg
    return head :forbidden if cfg[:admin] && !current_user.admin?
    return head :forbidden if cfg[:financiero] && !current_user.admin_financiero?

    @widget_name = name
    if name.start_with?('analytics_')
      local_id = current_user.tienda_activa.multiple_locales ? current_user.local_activo&.id : nil
      @analytics = Inicio::AnalyticsData.fetch(
        tienda: tienda_activa,
        local_id: local_id,
        es_admin_financiero: current_user.admin_financiero?
      )
    end

    respond_to do |format|
      format.js { render :widget }
    end
  end

  private

  def load_stock_alerts
    @stocks_criticos = Productos::Stock.none
    @stocks_bajos = Productos::Stock.none
    @stocks_proyectados = []
    @stock_aceptados_pendientes = Hash.new(0)
    return unless tienda_activa.maneja_stock?

    local_id = current_user.tienda_activa.multiple_locales ? current_user.local_activo&.id : nil

    stocks_alertables = Productos::Stock
                        .joins(:producto)
                        .joins('INNER JOIN categorias ON productos.categoria_id = categorias.id')
                        .where(tienda_id: tienda_activa.id, local_id: local_id)
                        .where(categorias: { stock_activo: true })
                        .where(productos: { discontinued_at: nil })
                        .where(activo: true)
                        .includes(:producto, producto: :categoria)
                        .order('productos.nombre ASC')
                        .to_a

    @stock_aceptados_pendientes = cantidades_aceptadas_por_stock(stocks_alertables, local_id)
    @stocks_criticos = stocks_alertables.select(&:stock_critico?).first(10)
    @stocks_bajos = stocks_alertables.select(&:stock_bajo?).first(10)
    @stocks_proyectados = stocks_alertables
                          .reject { |stock| stock.stock_critico? || stock.stock_bajo? }
                          .select { |stock| stock_actual_menos_aceptados(stock) <= stock.cantidad_minima }
                          .first(10)
  end

  def cantidades_aceptadas_por_stock(stocks, local_id)
    return Hash.new(0) if stocks.empty?

    product_ids = stocks.map(&:producto_id)
    solicitados = Productos::ProductoSolicitado
                  .joins(:pedido)
                  .where(producto_id: product_ids)
                  .where(pedidos: { tienda_id: tienda_activa.id, estado_id: Pedidos::Estado[:aceptado].id })
    solicitados = solicitados.where(pedidos: { local_id: local_id }) if local_id.present?

    cantidad_aceptada_sql = <<~SQL.squish
      CASE
        WHEN productos_solicitados.peso IS NOT NULL
        THEN productos_solicitados.cantidad * productos_solicitados.peso
        ELSE productos_solicitados.cantidad
      END
    SQL

    cantidades_por_producto = solicitados
                              .group(:producto_id)
                              .sum(cantidad_aceptada_sql)

    stocks.each_with_object(Hash.new(0)) do |stock, cantidades_por_stock|
      cantidades_por_stock[stock.id] = cantidades_por_producto[stock.producto_id].to_d
    end
  end

  def stock_actual_menos_aceptados(stock)
    stock.cantidad_actual - @stock_aceptados_pendientes[stock.id]
  end

  def load_precios_alerts
    # Cache key must bust when:
    #   - any precio in the tienda is created/updated (MAX updated_at)
    #   - any precio is deleted (COUNT changes)
    #   - any clientes_precios join row is added/removed (COUNT join rows)
    # The join-row count is needed because deleting from clientes_precios does
    # NOT touch precios.updated_at, so without it the alerts panel goes stale
    # after migrations or admin actions that unassign clientes from precios.
    precios_scope = Productos::Precio.joins(:producto)
                                     .where(productos: { tienda_id: tienda_activa.id })
    precios_max_updated = precios_scope.maximum(:updated_at).to_i
    precios_count = precios_scope.count
    cp_count = ActiveRecord::Base.connection.select_value(
      "SELECT COUNT(*) FROM clientes_precios cp
         INNER JOIN precios p ON p.id = cp.precio_id
         INNER JOIN productos pr ON pr.id = p.producto_id
        WHERE pr.tienda_id = #{tienda_activa.id.to_i}"
    ).to_i
    @precios_cache_key = "#{precios_max_updated}-#{precios_count}-#{cp_count}"

    return if fragment_exist?(['precios_alerts', tienda_activa.id, @precios_cache_key])

    cliente_prueba_ids = Clientes::Cliente.disponibles_en(tienda_activa)
                                          .where('clientes.nombre LIKE ?', '%prueba%').pluck(:id)

    # Step 1: pluck candidate precio IDs (active today, in this tienda, excluding prueba clients).
    # We do NOT use .includes(:clientes) here because combining it with
    # `joins(LEFT JOIN clientes_precios) + group('precios.id')` causes the
    # `.clientes` collection to load empty/wrong (same bug that affected
    # eliminar_duplicados — see Productos::ListasPreciosQuery#precios_for_dup_check).
    id_scope = Productos::Precio.joins(:producto)
                                .where(productos: { tienda_id: tienda_activa.id, discontinued_at: nil })
                                .where('precios.fecha_desde <= ? AND (precios.fecha_hasta >= ? OR precios.fecha_hasta IS NULL)',
                                       Time.zone.today, Time.zone.today)
                                .where(precios: { discontinued_at: nil })

    if cliente_prueba_ids.any?
      id_scope = id_scope
                 .joins('LEFT JOIN clientes_precios cp_excl ON cp_excl.precio_id = precios.id')
                 .where.not(cp_excl: { cliente_id: cliente_prueba_ids })
                 .group('precios.id')
    end

    candidate_ids = id_scope.reorder('').pluck(Arel.sql('precios.id'))

    # Step 2: reload via a clean scope so includes(:clientes) populates correctly.
    precios_activos = Productos::Precio.where(id: candidate_ids)
                                       .includes(:clientes, producto: :categoria)
                                       .to_a

    groups = precios_activos.group_by do |p|
      [p.clientes.map(&:id).sort, p.producto_id, p.importe.to_d, p.fecha_desde, p.fecha_hasta]
    end
    dup_ids = groups.select { |_, v| v.size > 1 }.values.flatten.map(&:id)
    @precios_duplicados_count = dup_ids.size

    # Productos sin precio activo hoy
    today = Time.zone.today
    @productos_sin_precio_count = Productos::Producto.active
                                                     .where(tienda_id: tienda_activa.id)
                                                     .where.not(
                                                       id: Productos::Precio.select(:producto_id)
                                                           .where('precios.fecha_desde <= ? AND (precios.fecha_hasta >= ? OR precios.fecha_hasta IS NULL)', today, today) # rubocop:disable Layout/LineLength
                                                     ).count
  end
end
