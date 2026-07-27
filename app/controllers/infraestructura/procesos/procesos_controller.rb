module Infraestructura
  module Procesos
    class ProcesosController < ApplicationController
      def index
        authorize! :index, :procesos
        @procesos = current_user.procesos.where(tienda_id: tienda_activa.id).order(created_at: :desc).includes(:autor,
                                                                                                               :progreso).page(params[:page])
      end

      def destroy
        @proceso = current_user.procesos.where(tienda_id: tienda_activa.id).find(params[:id])
        authorize! :destroy, @proceso
        @proceso.progreso.cancelar if @proceso.ejecutando? || @proceso.pendiente?
        @proceso.destroy
        redirect_to procesos_path, notice: 'El proceso fue eliminado.'
      end
    end
  end
end
