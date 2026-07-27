module Ventas
  module Facturacion
    class ComprobantesController < ApplicationController
      load_resource except: :index

      def index
        authorize! :index, Comprobante
        @query = ComprobantesQuery.new query_params.reverse_merge(emitidos_desde: Time.zone.today, estado_id: 2)
        respond_to do |format|
          format.any(:html, :js) { @comprobantes = @query.page(params[:page]).per_page(10) }
          format.xls do
            desde     = @query.emitidos_desde.presence || Time.zone.today.beginning_of_month
            hasta_val = @query.emitidos_hasta.presence || Time.zone.today
            desde, hasta_val = hasta_val, desde if desde > hasta_val
            meses = ((hasta_val.year - desde.year) * 12) + hasta_val.month - desde.month + 1
            if meses > VentasPorCategoriaExporter::MAX_MONTHS
              raise ErrorAplicacion, "El rango de fechas no puede superar los 10 años (#{VentasPorCategoriaExporter::MAX_MONTHS} meses)."
            end

            export_in_background VentasPorCategoriaExporter
          end
        end
      end

      def show
        @comprobante = Comprobante.includes(renglones: [:producto]).find params[:id]
        authorize! (request.format.pdf? ? :pdf_show : :show), @comprobante
        respond_to do |wants|
          wants.html
          wants.pdf { render_pdf silent_print: true }
        end
      end

      def new
        authorize! :new, Comprobante
        @comprobante = Comprobante.new
        @comprobante.renglones.build
      end

      def edit
        authorize! :edit, @comprobante
      end

      def create
        authorize! :index, @comprobante
        @comprobante.precios.clear
        @comprobante.assign_attributes comprobante_params
        if @comprobante.save
          redirect_to @comprobante, notice: "Comprobante #{@comprobante} creado correctamente."
        else
          render :new
        end
      end

      def update
        authorize! :update, @comprobante
        @comprobante.assign_attributes comprobante_params
        if @comprobante.save
          redirect_to @comprobante, notice: "Comprobante #{@comprobante} actualizado correctamente."
        else
          render :edit
        end
      end

      def comprobante_params
        params.require(:comprobante).permit(:nombre, :codigo, :descripcion, :precio, :active, :color, :categoria_id,
                                            documento_ids: [], precios_attributes: [:id, :fecha_desde, :fecha_hasta, :importe, :_destroy, { cliente_ids: [] }])
      end
    end
  end
end
