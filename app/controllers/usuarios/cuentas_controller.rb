module Usuarios
  class CuentasController < ApplicationController
    skip_before_action :password_not_expired_required, only: [:edit, :update]
    wrap_parameters :usuario, format: :json
    before_action { @user = current_user }

    def show
      @user = current_user
      @usuario = current_user
      authorize! :editar_cuenta, @usuario
      respond_to do |format|
        format.json
        format.html
      end
    end

    def actualizar_preferencias
      u = current_user
      authorize! :editar_cuenta, u
      pf = current_user.obtener_preferencia params[:nombre]
      pf.estado == false ? pf.update_column(:estado, true) : pf.update_column(:estado, false)
      respond_to do |format|
        format.html
      end
    end

    def cambiar_vista_productos
      authorize! :editar_cuenta, current_user
      vista = params[:vista].to_s
      unless Usuarios::Usuario::VISTAS_PRODUCTOS.include?(vista)
        head :unprocessable_entity
        return
      end
      current_user.update_column(:vista_productos, vista)
      respond_to do |format|
        format.js
      end
    end

    def edit
      authorize! :editar_cuenta, @user
    end

    def update
      authorize! :editar_cuenta, @user
      @user.attributes = usuario_params
      if usuario_params[:password].present? && Usuario.authenticate(current_user.login,
                                                                    params[:password_anterior])[:result] != :ok
        flash.now[:error] = 'La contraseña actual no coincide.'
        render :edit
      elsif @user.save
        @user.update_column :password_expires_at, Time.zone.local(2036, 1, 1) if @user.password_expired?
        respond_to do |format|
          format.html { redirect_back_or_default '/pedidos/new', notice: 'Cuenta actualizada correctamente.' }
          format.json { render :show }
        end
      else
        respond_to do |format|
          format.html { render :edit }
          format.json { render json: json_errors(@user), status: :unprocessable_entity }
        end
      end
    end

    def tipos_notificaciones
      authorize! :editar_cuenta, current_user
    end

    private

    def usuario_params
      params.require(:usuario).tap do |h|
        if h[:suscripciones]
          h[:suscripciones_attributes] = h.delete(:suscripciones).inject({}) do |h, s|
            h.merge s[:tipo_id] => s[:vias_ids]
          end
        end
      end.permit(:password, :password_confirmation, :email, :servicio_de_impresion_id, documento_ids: [], suscripciones_attributes: {})
    end
  end
end
