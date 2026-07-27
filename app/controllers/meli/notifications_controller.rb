module Meli
  class NotificationsController < ApplicationController
    skip_before_action :login_required
    skip_authorization_check
    skip_before_action :verify_authenticity_token

    def create
      Pedidos::MercadopagoUpdaterJob.perform_later params['id'] if params['id'].present? && params['topic'] == 'payment'
      render plain: 'OK', status: :ok
    end
  end
end
