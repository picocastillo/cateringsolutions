# Explicitly require controller concerns for Rails 7 Zeitwerk compatibility
require_relative 'concerns/authentication'
require_relative 'concerns/turbolinks_cache_control'
require_relative 'concerns/device_id'

class ApplicationController < SharedController
  acts_as_flying_saucer
  check_authorization

  helper :all

  protect_from_forgery with: :exception

  # Ensure proper execution order for before_actions
  before_action :login_required
  before_action :password_not_expired_required
  before_action :disable_browser_caching
  before_action :load_pedidos_cocina

  rescue_from CanCan::AccessDenied do |exception|
    logger.warn "Unauthorized access to #{exception.action} #{exception.subject.inspect}.\nUser: #{current_user} | Roles: #{current_user.roles.to_sentence}"
    show_error "Operación no válida! Por consultas, póngase en contacto con #{tienda_activa.nombre}. Whatsapp <a href='https://api.whatsapp.com/send?phone=+549#{tienda_activa.telefono}'>#{tienda_activa.telefono}</a>".html_safe,
               403
  end

  rescue_from Timeout::Error do
    show_error 'El tiempo de espera para su consulta ha sido demasiado. Por favor, intente ' \
               'nuevamente y de seguir fallando intente limitar la busqueda mediante filtros.',
               400
  end

  def test_exception_tanqueta
    raise 'Prueba de excepción.'
  end

  # Sin esto estos errores llegaban x mail
  unless Rails.configuration.consider_all_requests_local
    rescue_from ActionController::UnknownFormat do |_e|
      respond_to do |format|
        format.html { render file: Rails.public_path.join('406.html').to_s, status: :not_acceptable, layout: false }
        format.json { show_error 'Not Acceptable', 406 }
        format.any { head :not_acceptable }
      end
    end
  end

  def filtered_params
    clean_empty_string_in_arrays request.parameters.except(:commit, :utf8, :action, :controller, :format).to_h.deep_symbolize_keys
  end
  helper_method :filtered_params

  private

  # Serializes concurrent writes against the same pedido without holding any
  # row-level lock. Connection-scoped MariaDB advisory lock — does not interact
  # with transactions or savepoints, so it cannot deadlock with the request's
  # own callback chain or with the test thread.
  def with_pedido_upsert_lock(pedido_id, timeout: 5)
    conn = ActiveRecord::Base.connection
    name = "kiosk:actualizar_producto:#{pedido_id}"
    quoted = conn.quote(name)
    acquired = conn.select_value("SELECT GET_LOCK(#{quoted}, #{timeout.to_i})").to_i == 1
    yield
  ensure
    conn.select_value("SELECT RELEASE_LOCK(#{quoted})") if acquired
  end

  def load_pedidos_cocina
    return unless current_user&.admin? && tienda_activa&.carrito_de_compras

    generar_pedidos_a_cocinar
  end

  def generar_pedidos_a_cocinar
    day = Time.zone.today
    cache_key = "pedidos_cocina/#{tienda_activa.id}/#{day}"
    cached = Rails.env.test? ? nil : Rails.cache.read(cache_key)

    if cached
      @total_pedidos_hoy      = cached[:total]
      @pedidos_pendientes     = cached[:pendientes]
      @pedidos_listos_cocinar = cached[:listos]
      @pedidos_cocinados      = cached[:cocinados]
      @pedidos_pendientes_cortes = cached[:cortes]
      return
    end

    base = Pedidos::Pedido.where(tienda_id: tienda_activa, fecha: day, venta_mostrador: false)

    # Single query with conditional aggregation instead of 5 separate queries
    counters = base.where.not(estado_id: [1, 4, 5]).pick(
      Arel.sql('COUNT(*)'),
      Arel.sql('SUM(CASE WHEN estado_id = 2 AND pedido_cocina_id IS NULL THEN 1 ELSE 0 END)'),
      Arel.sql('SUM(CASE WHEN estado_id = 3 AND pedido_cocina_id IS NULL THEN 1 ELSE 0 END)'),
      Arel.sql('SUM(CASE WHEN estado_id = 3 AND pedido_cocina_id IS NOT NULL THEN 1 ELSE 0 END)')
    )

    @total_pedidos_hoy    = counters[0] || 0
    @pedidos_pendientes   = counters[1].to_i
    @pedidos_listos_cocinar = counters[2].to_i
    @pedidos_cocinados = counters[3].to_i

    @pedidos_pendientes_cortes = base.where.not(estado_id: [1, 4, 5])
                                     .joins(cuenta: :cliente)
                                     .distinct
                                     .pluck(Arel.sql('COALESCE(NULLIF(cuentas.horario_corte_pedidos, \'\'), clientes.horario_corte_pedidos)'))
                                     .compact_blank.uniq.sort

    Rails.cache.write(cache_key, {
                        total: @total_pedidos_hoy, pendientes: @pedidos_pendientes,
                        listos: @pedidos_listos_cocinar, cocinados: @pedidos_cocinados,
                        cortes: @pedidos_pendientes_cortes
                      }, expires_in: 30.seconds)
  end

  def validar_rango_fechas_exportacion!(max_dias, label: "#{max_dias} días")
    q = params[:q] || {}
    desde = q[:fecha_desde].presence&.to_date
    hasta = q[:fecha_hasta].presence&.to_date || Time.zone.today

    raise ErrorAplicacion, 'Debe especificar una fecha desde para exportar.' unless desde
    raise ErrorAplicacion, "El rango de fechas no puede superar los #{label}." if (hasta - desde).to_i > max_dias
  end

  def export_in_background(exporter_class)
    raise ErrorAplicacion, @query.errors.full_messages if @query&.invalid?

    exporter = exporter_class.create autor: current_user, tienda: tienda_activa, params: filtered_params
    Infraestructura::Procesos::LanzarProcesoJob.perform_later exporter
    redirect_to procesos_path, notice: 'La planilla se generará de fondo. En breve podrá descargarla.'
  end

  def export_in_foreground(exporter_class)
    exporter = exporter_class.create(autor: current_user, tienda: tienda_activa,
                                     params: filtered_params.merge(zippear: false)).perform
    send_file exporter.adjunto.path
  end

  def import_in_background(importer_class, redirect_to_default_path = true)
    proceso = importer_class.new (request.parameters.delete(:proceso) || {}).merge(autor: current_user,
                                                                                   tienda: tienda_activa)
    raise ErrorAplicacion, proceso.errors.full_messages unless proceso.save

    Infraestructura::Procesos::LanzarProcesoJob.perform_later proceso
    redirect_to procesos_path, notice: 'La planilla importará en breve.' if redirect_to_default_path
  end

  def print_on_load(value = true, id = nil)
    session[:print_on_load] = value unless Rails.env.test?
    session[:print_on_load_id] = id unless Rails.env.test?
  end

  def clean_empty_string_in_arrays(hash)
    return unless hash

    hash.each_value do |v|
      case v
      when Array then v.reject!(&:blank?)
      when Hash then clean_empty_string_in_arrays(v)
      end
    end
  end

  def query_params
    clean_empty_string_in_arrays (request.parameters[:q].is_a?(String) ? nil : request.parameters[:q]).to_h.merge user: current_user
  end

  def disable_browser_caching
    response.headers['Cache-Control'] = 'no-cache, no-store, max-age=0, must-revalidate'
    response.headers['Pragma'] = 'no-cache'
    response.headers['Expires'] = 'Fri, 01 Jan 1990 00:00:00 GMT'
  end

  def new_modal_form
    respond_to do |format|
      format.js { render '/application/new_modal_form' }
    end
  end

  def create_modal_form(model, notice: nil)
    @model = model
    @notice = notice
    respond_to do |format|
      format.js { render '/application/create_modal_form' }
    end
  end
end
