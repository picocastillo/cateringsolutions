module Pedidos
  module Despachos
    class EtiquetasController < ApplicationController
      def index
        authorize! :index, :despachos
        tienda_first_local = current_user.tienda_activa&.locales&.first
        default_local_id = current_user.local_activo&.id || tienda_first_local&.id
        etiquetas_params = query_params.reverse_merge(
          fecha_desde: Time.zone.today,
          fecha_hasta: Time.zone.today,
          local_id: default_local_id
        ).merge(venta_mostrador: 'false')
        if etiquetas_params[:fecha_desde].present? && etiquetas_params[:fecha_hasta].present? &&
           (etiquetas_params[:fecha_hasta].to_date - etiquetas_params[:fecha_desde].to_date).to_i > 3
          etiquetas_params[:fecha_hasta] = (etiquetas_params[:fecha_desde].to_date + 3.days).to_s
        end
        @query = Productos::ProductosSolicitadosQuery.new(etiquetas_params.merge(fecha_obligatoria: true))
        if @query.valid?
          respond_to do |format|
            format.any :html, :js do
              @despachos = @query.crear_grupos(@query.relation)
                                 .includes(:menu_diario, pedido: [{ cuenta: :cliente }, :usuario], producto: [:categoria])
                                 .to_a
            end
            format.xls do
              params[:q] ||= {}
              params[:q][:fecha_desde] = etiquetas_params[:fecha_desde]
              params[:q][:fecha_hasta] = etiquetas_params[:fecha_hasta]
              export_in_background ReporteDespachoExporter
            end
            format.pdf do
              @despachos = @query.base_query
              render_pdf silent_print: true if @despachos.present?
            end
          end
        else
          @despachos = []
          flash.now[:error] = @query.errors
        end
      end

      def new
        authorize! :index, :despachos
      end

      def importar_etiquetas_williner
        authorize! :index, :despachos
        if params[:proceso] && params[:proceso][:adjunto]&.tempfile
          respond_to do |format|
            format.pdf do
              spreadsheet = Roo::Spreadsheet.open params[:proceso][:adjunto].tempfile
              sheet = spreadsheet.sheet(0)
              @etiquetas = []
              (1..sheet.last_row).each do |row_idx|
                row = sheet.row(row_idx)
                next if row.compact.empty? || row_idx < 3

                @etiquetas << [row[0], row[1], row[2], row[3]]
              end
              render_pdf silent_print: true
            end
          end
        else
          redirect_to etiquetas_path
        end
      end
    end
  end
end
