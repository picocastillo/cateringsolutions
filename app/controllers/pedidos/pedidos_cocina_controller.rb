module Pedidos
  # Controller responsible for managing kitchen orders and their related actions.
  class PedidosCocinaController < ApplicationController
    def index
      authorize! :index, Pedidos::PedidoCocina
      respond_to do |format|
        format.any :html, :js do
          @filtro_abierto = params[:show_filtro].present?
          @query = Pedidos::PedidosCocinaQuery.new query_params.merge(user: current_user)
          @query.fecha_desde = Time.zone.today if params[:q].blank? && @query.fecha_desde.blank? && !current_user.cliente?
          @pedidos_cocina = @query.relation.paginate(page: params[:page], per_page: 10)
        end
        format.xls { export_in_background ResumenPedidosExporter }
      end
    end

    def show
      # Eager load to avoid N+1s in view
      @pedido_cocina = Pedidos::PedidoCocina
                       .includes(:autor, :tienda, pedidos: [:cuenta, :usuario, :productos_solicitados])
                       .find(params[:id])
      authorize! :show, @pedido_cocina
      respond_to do |format|
        format.html
        format.xls { export_in_background ReportePedidoCocinaExporter }
      end
    end

    def new
      authorize! :create, Pedidos::PedidoCocina
      find_pedidos
      @pedido_cocina = Pedidos::PedidoCocina.new tienda: current_user.tienda_activa, autor: current_user
    end

    def find_pedidos
      authorize! :create, Pedidos::PedidoCocina
      @query = Pedidos::PedidosQuery.new(
        query_params
          .reverse_merge(fecha_desde: Time.zone.today, fecha_hasta: Time.zone.today).merge(estado_id: 3, sin_pedido_cocina: true, user: current_user)
      )
      @pedidos_a_cocinar = @query.relation.includes(:productos_solicitados, :tienda, cuenta: :cliente)

      respond_to do |format|
        if params[:commit] == 'Crear'
          if @pedidos_a_cocinar.empty?
            format.html do
              redirect_to new_pedido_cocina_path, alert: 'No hay pedidos listos para cocinar en la fecha seleccionada.'
            end
          else
            @pedidos_a_cocinar.each do |pedido|
              pedido.no_validar_fecha = true
            end

            # Pre-validate each pedido and collect per-pedido errors so the
            # flash message is actionable instead of just "Pedidos no es valido".
            pedidos_invalidos = @pedidos_a_cocinar.reject(&:valid?)
            if pedidos_invalidos.any?
              detalles = pedidos_invalidos.map do |p|
                "Pedido ##{p.codigo} (#{p.cuenta&.cliente&.nombre} / #{p.fecha&.strftime('%d/%m/%Y')}): #{p.errors.full_messages.join(', ')}"
              end.join(' | ')
              format.html do
                flash.now[:alert] = "No se pudo crear el pedido de cocina. Pedidos inválidos: #{detalles}"
                render :new
              end
            else
              @pedido_cocina = Pedidos::PedidoCocina.new tienda: current_user.tienda_activa, autor: current_user,
                                                         pedidos: @pedidos_a_cocinar
              if @pedido_cocina.save
                format.html do
                  redirect_to pedido_cocina_path(@pedido_cocina), notice: 'Pedido de cocina creado exitosamente.'
                end
              else
                # Fallback: something on PedidoCocina itself failed (e.g. codigo)
                format.html do
                  flash.now[:alert] =
                    "Error al crear el pedido de cocina: #{@pedido_cocina.errors.full_messages.join(', ')}"
                  render :new
                end
              end
            end
          end
        else
          # This is a search request
          format.js # renders find_pedidos.js.erb
          format.html { render :new }
        end
      end
    end

    def destroy
      @pedido_cocina = Pedidos::PedidoCocina.find(params[:id])
      authorize! :destroy, @pedido_cocina
      nombre = @pedido_cocina.to_s
      @pedido_cocina.destroy!
      redirect_to pedidos_cocina_path, notice: "#{nombre} eliminado correctamente."
    end

    private

    def query_params
      params.fetch(:q, {}).permit(:fecha_desde, :fecha_hasta, :usuario_ids, :cliente_ids, :cuenta_ids, :cuentas_ids,
                                  cliente_ids: [], cuenta_ids: [], cuentas_ids: [], horarios_de_corte_ids: [])
    end
  end
end
