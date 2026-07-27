module Ventas
  module Facturacion
    class SaldosController < ApplicationController
      load_resource except: :index
      def index
        authorize! :index, Contabilidad::Movimiento
        @query = Contabilidad::SaldosMovimientosQuery.new query_params
        @query.visualizar_por_id = 1 if params[:q].blank?
        respond_to do |format|
          format.any :html, :js do
            @movimientos = @query.page(params[:page]).per_page(20)
          end
          format.xls { export_in_background Contabilidad::SaldosCuentasCorrientesExporter }
        end
      end
    end
  end
end
