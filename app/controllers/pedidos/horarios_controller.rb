module Pedidos
  class HorariosController < ApplicationController
    def index
      authorize! :index, Horario
      respond_to do |format|
        format.html do
          @horarios = Horario.where(tienda_id: tienda_activa.id).order(:position).paginate(page: params[:page],
                                                                                           per_page: 10)
        end
        format.json do
          @horarios = Horario.where(tienda_id: tienda_activa.id).active.order(:position)
          render json: @horarios.map { |t| { id: t.id, nombre: t.nombre, horario: t.horario } }
        end
      end
    end

    def new
      authorize! :new, Horario
      @horario = Horario.new tienda: tienda_activa
      new_modal_form
    end

    def edit
      @horario = Pedidos::Horario.where(tienda_id: tienda_activa.id, id: params[:id]).first
      authorize! :edit, @horario
      new_modal_form
    end

    def create
      @horario = Horario.new horario_params.merge(tienda_id: tienda_activa.id)
      authorize! :create, @horario
      @horario.save
      create_modal_form @horario,
                        notice: "Horario de entrega <strong>#{@horario}</strong> creado correctamente.".html_safe
    end

    def update
      @horario = Pedidos::Horario.where(tienda_id: tienda_activa.id, id: params[:id]).first
      authorize! :update, @horario
      @horario.assign_attributes horario_params.merge(tienda_id: tienda_activa.id)
      @horario.save
      create_modal_form @horario,
                        notice: "Horario de entrega <strong>#{@horario}</strong> actualizado correctamente.".html_safe
    end

    def destroy
      @horario = Pedidos::Horario.where(tienda_id: tienda_activa.id, id: params[:id]).first
      authorize! :destroy, @horario
      @horario.destroy!
      create_modal_form @horario,
                        notice: "Horario de entrega <strong>#{@horario}</strong> eliminado correctamente.".html_safe
    end

    def horario_params
      params.require(:horario).permit(:nombre, :horario, :active, :tienda_id, :por_defecto)
    end
  end
end
