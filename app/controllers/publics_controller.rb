class PublicsController < ApplicationController
  skip_authorization_check
  before_action :login_required, except: [:show, :create, :manifest]
  skip_before_action :password_not_expired_required
  skip_before_action :disable_browser_caching, only: :manifest
  skip_before_action :load_pedidos_cocina, only: :manifest

  layout 'public'

  def show
    return unless current_user

    if current_user.tienda_activa.carrito_de_compras?
      redirect_to(current_user.cuenta ? '/pedidos/new' : '/inicio')
    else
      redirect_to('/inicio')
    end
  end

  def create
    auth_result = Usuarios::Usuario.authenticate params[:username]&.strip, params[:password]&.strip, tienda_activa
    respond_to do |format|
      format.html { handle_html_auth auth_result }
      format.json { handle_json_auth auth_result }
    end
  end

  def destroy
    cookies.delete :auth_token
    reset_session
    redirect_back_or_default '/'
  end

  def manifest
    @tienda = tienda_activa
    expires_in 1.day, public: true
    body = Rails.cache.fetch(['publics/manifest', @tienda.id, @tienda.updated_at.to_i]) do
      render_to_string(layout: false)
    end
    render plain: body, content_type: 'application/manifest+json'
  end

  private

  def handle_html_auth(auth_result)
    if auth_result[:result] == :ok
      self.current_authenticated_user = auth_result[:user]
      # Reset the cached tienda_activa so it re-evaluates now that we have a
      # current_user. Without this, the value cached during authenticate() (when
      # current_user was nil → Tiendas::Tienda.first) would be reused here.
      @tienda_activa = nil
      # Always land on the tienda resolved from the domain used to log in.
      # This ensures clientes arriving at tienda2.example.com start in tienda 2
      # even if their last session was on a different tienda.
      login_tienda = tienda_activa
      if login_tienda && current_user.puede_loguearse_en?(login_tienda)
        current_user.update_columns(
          visualizando_tienda_id: login_tienda.id,
          tienda_cliente_id: login_tienda.id,
          visualizando_local_id: nil
        )
        current_user.unmemoize_all if current_user.respond_to?(:unmemoize_all)
      end
      path = if current_user.tienda_activa.carrito_de_compras?
               current_user.cuenta ? '/pedidos/new' : '/inicio'
             else
               '/inicio'
             end
      redirect_back_or_default path
    else
      self.current_authenticated_user = nil # Por si ya estaba logueado cuando se lo desactiva
      flash.now[:error] = I18n.t("flash.auth_result.#{auth_result[:result]}")
      render :show
    end
  end

  def handle_json_auth(auth_result)
    if auth_result[:result] == :ok
      user = auth_result[:user]
      login_tienda = tienda_activa
      if login_tienda && user.puede_loguearse_en?(login_tienda)
        user.update_columns(
          visualizando_tienda_id: login_tienda.id,
          tienda_cliente_id: login_tienda.id,
          visualizando_local_id: nil
        )
      end
      render json: { token: AuthToken.encode(id: user.id, username: user.login, nombre: user.nombre) }
    else
      render json: { error: I18n.t("flash.auth_result.#{auth_result[:result]}") }, status: :unauthorized
    end
  end
end
