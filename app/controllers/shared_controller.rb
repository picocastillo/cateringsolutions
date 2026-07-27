class SharedController < ActionController::Base
  include Authentication
  include TurbolinksCacheControl
  extend TransactionInterceptor

  helper_method :current_user
  helper_method :tienda_activa

  after_action :log_metricas

  def current_user
    @current_user ||= current_authenticated_user
  end

  def tienda_activa
    @tienda_activa ||= buscar_tienda_activa
  end

  rescue_from ErrorAplicacion, InvalidQuery do |e|
    show_error e.message, 400
  end

  private

  def show_error(msg, status)
    respond_to do |format|
      format.any :js, :html do
        flash.now[:error] = msg
        render 'application/error', status: status
      end
      format.any :pdf, :xls do
        flash[:error] = msg
        redirect_back_or_to(root_path)
      end
      format.json do
        render json: { error: msg, status: status }, status: status
      end
    end
  end

  def buscar_tienda_activa
    if current_user
      # No domain-based realignment: the tienda switcher (admins and clientes)
      # explicitly sets visualizando_tienda_id and redirects on the SAME domain.
      # Realigning here would silently revert switches done from a single
      # subdomain.
      current_user.tienda_activa
    else
      Tiendas::Tienda.find_by(dominio: request.domain(2)) || Tiendas::Tienda.first
    end
  end

  def log_metricas
    ip = request.env['metricas.ip'] || request.remote_ip
    mobile = request.env['metricas.mobile']
    mobile = false if mobile.nil?
    tid = tienda_activa&.id || 0
    uid = current_user&.id || 0
    Rails.logger.info "[METRICS] ip=#{ip} mobile=#{mobile} tienda_id=#{tid} usuario_id=#{uid}"
    request.env['metricas.logged'] = true
  rescue StandardError
    # Never break the request for metrics logging
  end
end
