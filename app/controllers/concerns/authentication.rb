module Authentication
  # Inclusion hook to make #current_authenticated_user and #logged_in?
  # available as ActionView helper methods.
  def self.included(base)
    base.send :helper_method, :current_authenticated_user, :logged_in?
  end

  protected

  # Returns true or false if the user is logged in.
  # Preloads @current_authenticated_user with the user model if they're logged in.
  def logged_in?
    !!current_user
  end

  # Accesses the current user from the session.
  # Future calls avoid the database because nil is not equal to false.
  def current_authenticated_user
    return if @current_authenticated_user == false

    @current_authenticated_user ||= login_from_session || login_from_basic_auth || login_from_cookie

    # Guard against corrupted session data (e.g., Hash from old Marshal-serialized sessions)
    unless @current_authenticated_user.nil? || @current_authenticated_user.is_a?(Usuarios::Usuario)
      @current_authenticated_user = false
      reset_session
      return
    end

    if @current_authenticated_user.is_a?(Usuarios::Usuario) &&
       (session_record = ActiveRecord::SessionStore::Session.where(session_id: session.id.to_s).first) &&
       session_record.user_id.blank?
      session_record.update_column(:user_id, @current_authenticated_user.id)
    end
    @current_authenticated_user
  end

  # Store the given user id in the session.
  def current_authenticated_user=(new_user)
    @current_authenticated_user = false
    return unless new_user.is_a?(Usuarios::Usuario)

    session[:user_id] = new_user.id
    if session[:user_id]
      cookies.encrypted['user_id'] = {
        value: session[:user_id],
        secure: !Rails.env.local?
      }
    end

    # Update the session record with user_id
    if (session_record = ActiveRecord::SessionStore::Session.where(session_id: session.id.to_s).first) && session_record.user_id.blank?
      session_record.update_column(:user_id, session[:user_id])
    end

    @current_authenticated_user = new_user || false
  end

  # Check if the user is authorized
  #
  # Override this method in your controllers if you want to restrict access
  # to only a few actions or if you want to check if the user
  # has the correct rights.
  #
  # Example:
  #
  #  # only allow nonbobs
  #  def authorized?
  #    current_authenticated_user.login != "bob"
  #  end
  def authorized?
    logged_in?
  end

  # Filter method to enforce a login requirement.
  #
  # To require logins for all actions, use this in your controllers:
  #
  #   before_filter :login_required
  #
  # To require logins for specific actions, use this in your controllers:
  #
  #   before_filter :login_required, :only => [ :edit, :update ]
  #
  # To skip this in a subclassed controller:
  #
  #   skip_before_filter :login_required
  #
  def login_required
    if authorized?
      if current_user.cliente && (!current_user.cuenta.cliente.active? || !current_user.cuenta.active?)
        cookies.delete :auth_token
        reset_session
        redirect_to '/', flash: { error: 'Tu empresa está desactivada.' }
      end
    else
      access_denied
    end
  end

  def password_not_expired_required
    return unless current_user&.password_expired?

    respond_to do |format|
      format.html do
        redirect_to edit_cuenta_path,
                    flash: { error: 'Tu contraseña ha vencido. Por favor ingresá una nueva contraseña.' }
      end
      format.json do
        render json: { error: 'Tu contraseña ha vencido, por favor actualizala ingresando desde la web app.' },
               status: 550
      end
    end
  end

  # Redirect as appropriate when an access request fails.
  #
  # The default action is to redirect to the login screen.
  #
  # Override this method in your controllers if you want to have special
  # behavior in case the user is not authorized
  # to access the requested action.  For example, a popup window might
  # simply close itself.
  def access_denied
    respond_to do |format|
      format.html do
        store_location
        redirect_to '/' unless request.path == '/'
      end
      format.any do
        request_http_basic_authentication 'Rosa'
      end
    end
  end

  # Store the URI of the current request in the session.
  #
  # We can return to this location by calling #redirect_back_or_default.
  def store_location
    session[:return_to] = request.fullpath
  end

  # Redirect to the URI stored by the most recent store_location call or
  # to the passed default.
  def redirect_back_or_default(default, opts = {})
    redirect_to(session[:return_to] || default, opts)
    session[:return_to] = nil
  end

  # Called from #current_authenticated_user.  First attempt to login by the user id stored in the session.
  def login_from_session
    return unless session[:user_id]

    self.current_authenticated_user = Usuarios::Usuario.where(id: session[:user_id]).includes(
      :tienda_cliente, :visualizando_tienda, :preferencias, :favoritos, cuenta: :cliente
    ).first
  end

  # Called from #current_authenticated_user.  Now, attempt to login by basic authentication information.
  def login_from_basic_auth
    authenticate_with_http_basic do |username, password|
      self.current_authenticated_user = Usuarios::Usuario.authenticate(username, password)
    end
  end

  def login_from_cookie
    return unless cookies['_kiosk_session']

    saved_session = ActiveRecord::SessionStore::Session.where(session_id: cookies['_kiosk_session']).first
    user = saved_session&.user_id && Usuarios::Usuario.where(id: saved_session.user_id).includes(
      :tienda_cliente, :visualizando_tienda, :preferencias, :favoritos
    ).first
    return unless user&.active?

    self.current_authenticated_user = user
  end
end
