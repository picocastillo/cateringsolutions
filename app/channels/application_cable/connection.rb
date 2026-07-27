module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      self.current_user = find_verified_user
    end

    private

    def find_verified_user
      # Try multiple authentication methods similar to your controller concern
      user = find_user_from_cookie || find_user_from_session || find_user_from_encrypted_cookie

      # In production, reject unauthorized connections
      reject_unauthorized_connection if Rails.env.production? && (user.nil? || user.cliente?)

      # In development, allow any authenticated user but log the result
      unless Rails.env.production?
        if user
          logger.info "Action Cable: Authenticated user #{user.id} (#{user.cliente? ? 'cliente' : 'admin'})"
        else
          logger.warn 'Action Cable: No authenticated user found'
        end
      end

      user
    rescue ActiveRecord::RecordNotFound => e
      logger.warn "Action Cable: User session not found - #{e.message}"
      Rails.env.production? ? reject_unauthorized_connection : nil
    end

    def find_user_from_cookie
      if cookies['_kiosk_session'].present?
        saved_session = ActiveRecord::SessionStore::Session.where(session_id: cookies['_kiosk_session']).first
        if saved_session&.user_id
          user = Usuarios::Usuario.where(id: saved_session.user_id)
                                  .includes(:tienda_cliente, :visualizando_tienda)
                                  .first
          return user if user&.active?
        end
      end
      nil
    end

    def find_user_from_session
      # Try to get user from Rails session if available
      if request.session && request.session[:user_id]
        user = Usuarios::Usuario.where(id: request.session[:user_id])
                                .includes(:tienda_cliente, :visualizando_tienda)
                                .first
        return user if user&.active?
      end
      nil
    end

    def find_user_from_encrypted_cookie
      # Try encrypted cookie as fallback
      if cookies.encrypted['user_id'].present?
        user = Usuarios::Usuario.where(id: cookies.encrypted['user_id'])
                                .includes(:tienda_cliente, :visualizando_tienda)
                                .first
        return user if user&.active?
      end
      nil
    end
  end
end
