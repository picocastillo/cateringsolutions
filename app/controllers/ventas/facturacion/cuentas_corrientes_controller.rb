module Ventas
  module Facturacion
    class CuentasCorrientesController < ApplicationController
      load_resource except: :index

      def index
        authorize! :index, Contabilidad::Movimiento
        @query = Contabilidad::RenglonesMovimientosQuery.new query_params.merge(para_pdf: request.format.pdf?)
        @query.desde = 1.month.ago.beginning_of_month.to_date if params[:q].blank? && @query.desde.blank?
        respond_to do |format|
          format.any :html, :js do
            @movimientos = @query.movimientos_con_saldos(params[:page], 20)
          end
          format.xls { export_in_background Contabilidad::CuentasCorrientesExporter }
        end
      end
    end
  end
end
