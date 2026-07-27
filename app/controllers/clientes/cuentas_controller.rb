module Clientes
  class CuentasController < ApplicationController
    load_and_authorize_resource except: [:index]

    def index
      respond_to do |format|
        format.json do
          authorize! :index_js, Cuenta
          if params[:for_autocomplete] == 'true'
            render json: Clientes::CuentasParaAcQuery.new(request.parameters.merge(user: current_user)).limit(10)
                         .to_json(only: :id, methods: [:cliente_y_nombre, :to_s])
          else
            if current_user.admin?
              q = Clientes::Cuenta.joins(:cliente).where(
                'cuentas.nombre like ? or clientes.nombre like ? or cuentas.nro = ?',
                "%#{request.parameters[:q]}%", "%#{request.parameters[:q]}%",
                request.parameters[:q]
              )
              q = q.status(:active) if request.parameters[:active] == 'true'
            else
              q = current_user.cumple_rol?(:administrador_empresa) ? current_user.cuenta.cliente.cuentas.to_a : []
            end
            render json: q.to_json(only: :id, methods: [:cliente_y_nombre])
          end
        end
      end
    end
  end
end
