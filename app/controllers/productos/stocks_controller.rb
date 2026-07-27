module Productos
  class StocksController < ApplicationController
    load_resource except: :index

    def index
      authorize! :index, Stock
      respond_to do |format|
        format.any :html, :js do
          @query = StocksQuery.new query_params
          @stocks = @query.page(params[:page]).per_page(20)
          @resumen_stocks = @query.resumen_stocks if @stocks.any?
        end
        format.json do
          @query = StocksQuery.new query_params.merge(busqueda: params[:q])
          render json: @query.page(params[:page]).per_page(10).to_json(
            include: {
              producto: { only: [:id, :nombre, :codigo] },
              tienda: { only: [:id, :nombre] },
              local: { only: [:id, :nombre] }
            },
            methods: [:stock_bajo?, :stock_critico?, :disponible?]
          )
        end
        format.xls { export_in_background Productos::StocksExporter }
      end
    end

    def show
      authorize! :show, @stock
    end

    def edit
      authorize! :edit, @stock
    end

    def update
      authorize! :update, @stock
      @stock.assign_attributes stock_params
      if @stock.save
        redirect_to @stock, notice: 'Stock actualizado correctamente.'
      else
        render :edit
      end
    end

    def import
      authorize! :manage, Stock
      return unless tienda_activa.dominio == request.domain(2) || Rails.env.development?

      import_in_background Productos::StocksImporter
    end

    def ajustar_stock
      authorize! :update, @stock
      nueva_cantidad = movimientos_params[:nueva_cantidad].to_i
      motivo = movimientos_params[:motivo].presence || 'Ajuste manual'

      if @stock.ajustar_stock(nueva_cantidad, motivo, current_user)
        flash[:notice] = "Stock ajustado correctamente. Nueva cantidad: #{nueva_cantidad}"
      else
        flash[:error] = "Error al ajustar stock: #{@stock.errors.full_messages.join(', ')}"
      end

      redirect_to @stock
    end

    def movimientos
      authorize! :show, @stock
      @movimientos = @stock.stock_movimientos.includes(:usuario).order(fecha: :desc)
                           .page(params[:page]).per_page(20)
      render layout: false if request.xhr?
    end

    private

    def stock_params
      # Accept both :productos_stock and :stock parameter keys
      # NOTE: cantidad_actual is excluded - changes must go through ajustar_stock to maintain audit trail
      key = params.key?(:productos_stock) ? :productos_stock : :stock
      params.require(key).permit(:cantidad_minima, :cantidad_maxima, :observaciones, :activo)
    end

    def movimientos_params
      params.permit(:nueva_cantidad, :motivo)
    end
  end
end
