module CargasSimples
  class PedidosController < ApplicationController
    before_action :disable_turbolinks_cache
    load_resource class: Pedidos::Pedido, only: [:destroy, :edit, :update]

    def index
      @pedido = if params[:last_user].present?
                  Pedidos::Pedido.new(autor: current_user, estado_id: 1, fecha: nil,
                                      tienda_id: tienda_activa.id, usuario: Usuarios::Usuario.find(params[:last_user].to_i))
                else
                  Pedidos::Pedido.new(
                    autor: current_user, estado_id: 1, fecha: nil, tienda_id: tienda_activa.id
                  )
                end
      authorize! :carga_rapida, @pedido
      @pedido.cargando.productos_solicitados.build [{ cantidad: 1 }, { cantidad: 1 }, { cantidad: 1 }] if @pedido.usuario.present?
      if params[:last_date].present?
        d_s = params[:last_date].to_date + 1.day
        @pedido.fecha = d_s
      end
      respond_to do |format|
        format.any :html, :js do
          @query = Pedidos::PedidosQuery.new query_params.merge(carga_simple: true)
          @pedidos = @query.reorder(nil).order('pedidos.updated_at desc')
                           .includes(usuario: [cuenta: :cliente], cuenta: :cliente, productos_solicitados: :producto)
                           .page(params[:page]).per_page(5)
          # Pre-load data used by views to avoid view-level queries
          @cuentas_cs = Clientes::Cuenta.joins(cliente: :tiendas).where(tiendas: { id: tienda_activa.id }).active.distinct
          @horarios_cs = Pedidos::Horario.where(tienda_id: tienda_activa).active if tienda_activa.horarios_de_entrega?
        end
      end
    end

    def edit
      authorize! :edit_rapido, @pedido
      @query = Pedidos::PedidosQuery.new query_params.merge(carga_simple: true)
      @pedidos = @query.reorder(nil).order('pedidos.created_at desc')
                       .includes(usuario: [cuenta: :cliente], cuenta: :cliente, productos_solicitados: :producto)
                       .page(params[:page]).per_page(5)
      @pedido.cargando.productos_solicitados.build [{ cantidad: 1 }, { cantidad: 1 }, { cantidad: 1 }]
      render :index
    end

    def create
      authorize! :carga_rapida, Pedidos::Pedido
      env = params[:pedido].delete(:enviar_a_id)
      hor = params[:pedido].delete(:horario_id)
      dir = params[:pedido].delete(:direccion_envio)
      dedupe_productos_solicitados_attributes!
      @pedido = Pedidos::Pedido.new pedido_params.merge(autor: current_user, estado_id: 1)
      @pedido.asignar_cuenta_manual
      @pedido.cuenta ||= @pedido.usuario&.cuenta
      error = @pedido.productos_solicitados.present? ? '' : 'Debe seleccionar productos.'
      @pedido.no_validar_fecha = true
      @pedido.facturando
      if env.present? && (@pedido.cuenta.cliente.permitir_envios_a_domicilio || @pedido.cuenta.cliente.usuario_puede_elegir_cuenta)
        @pedido.enviar_a_id = env
        @pedido.direccion_envio = dir if dir.present?
      end
      @pedido.horario_id = hor.to_i if hor.present? && @pedido.cuenta.cliente.horarios_de_entrega? && tienda_activa.horarios_de_entrega?
      if error.blank? && @pedido.save
        @pedido.aceptar!(current_user)
        @pedido.usuario.update_column :direccion_envio, @pedido.direccion_envio if @pedido.envio_a_domicilio
        @query = Pedidos::PedidosQuery.new query_params.merge(carga_simple: true)
        @pedidos = @query.reorder(nil).order('pedidos.created_at desc')
                         .includes(usuario: [cuenta: :cliente], cuenta: :cliente)
                         .page(params[:page]).per_page(5)
        cta = @pedido.cuenta || @pedido.usuario&.cuenta
        hce = cta.hora_corte_efectiva
        fecha = hce == '00:00' ? (@pedido.fecha - 1.day) : @pedido.fecha
        hc = hce == '00:00' ? '23:59' : hce
        ms = if @pedido.confirmado?
               'El pedido ya habia sido Confirmado por lo que se creará una Nota de Crédito ' \
                 'anulando el Remito creado por el pedido original. Se creará un nuevo Remito ' \
                 'contemplando los cambios realizados.'
             elsif fecha < Time.zone.today
               'El mismo fue Aceptado y pasara a estado Confirmado en unos minutos.'
             else
               "El mismo fue Aceptado y será editable hasta las #{hc}hs del #{fecha} " \
                 'cuando el mismo pase a estado Confirmado.'
             end
        redirect_to cargas_simples_pedidos_path(last_user: @pedido.usuario.try(:id),
                                                last_date: @pedido.fecha.to_s),
                    notice: "Pedido </strong>#{@pedido}</strong> cargado correctamente. #{ms}"
      else
        @query = Pedidos::PedidosQuery.new query_params.merge(carga_simple: true)
        @pedidos = @query.reorder(nil).order('pedidos.created_at desc')
                         .includes(usuario: [cuenta: :cliente], cuenta: :cliente)
                         .page(params[:page]).per_page(5)
        if error.present?
          @pedido.cargando.productos_solicitados.build [{ cantidad: 1 }, { cantidad: 1 }, { cantidad: 1 }]
          @pedido.errors.add :base, error
        end
        render :index
      end
    end

    def update
      authorize! :edit_rapido, @pedido
      dedupe_productos_solicitados_attributes!
      @pedido.assign_attributes pedido_params
      @pedido.productos_solicitados.each(&:actualizar_precio)
      error = @pedido.productos_solicitados.present? ? '' : 'Debe seleccionar productos.'
      @pedido.no_validar_fecha = true
      @pedido.facturando
      if @pedido.save
        cta = @pedido.cuenta || @pedido.usuario&.cuenta
        @pedido.usuario.update_column :direccion_envio, @pedido.direccion_envio if @pedido.envio_a_domicilio
        @query = Pedidos::PedidosQuery.new query_params.merge(carga_simple: true)
        @pedidos = @query.reorder(nil).order('pedidos.created_at desc')
                         .includes(usuario: [cuenta: :cliente], cuenta: :cliente)
                         .page(params[:page]).per_page(5)
        hce = cta.hora_corte_efectiva
        fecha = hce == '00:00' ? (@pedido.fecha - 1.day) : @pedido.fecha
        hc = hce == '00:00' ? '23:59' : hce
        ms = if @pedido.confirmado?
               'El pedido ya habia sido Confirmado por lo que se creará una Nota de Crédito ' \
                 'anulando el Remito creado por el pedido original. Se creará un nuevo Remito ' \
                 'contemplando los cambios realizados.'
             elsif fecha < Time.zone.today
               'El mismo fue Aceptado y pasara a estado Confirmado en unos minutos.'
             else
               "El mismo fue Aceptado y será editable hasta las #{hc}hs del #{fecha} " \
                 'cuando el mismo pase a estado Confirmado.'
             end
        redirect_to cargas_simples_pedidos_path(last_user: @pedido.usuario.try(:id)),
                    notice: "Pedido <strong>#{@pedido}</strong> cargado correctamente. #{ms}"
      else
        @query = Pedidos::PedidosQuery.new query_params.merge(carga_simple: true)
        @pedidos = @query.reorder(nil).order('pedidos.created_at desc')
                         .includes(usuario: [cuenta: :cliente], cuenta: :cliente)
                         .page(params[:page]).per_page(5)
        if error.present?
          @pedido.cargando.productos_solicitados.build [{ cantidad: 1 }, { cantidad: 1 }, { cantidad: 1 }]
          @pedido.errors.add :base, error
        end
        render :index
      end
    end

    def destroy
      authorize! :destroy, @pedido
      nombre = @pedido.pendiente? ? '' : @pedido.to_s
      @pedido.destroy!
      redirect_to cargas_simples_pedidos_path, notice: "Pedido #{nombre} eliminado correctamente."
    end

    def cambiar_usuario
      authorize! :carga_rapida, Pedidos::Pedido
      u = if current_user.cuenta
            current_user
          else
            (pedido_params[:usuario_id].present? ? Usuarios::Usuario.find(pedido_params[:usuario_id].to_i) : nil)
          end
      c = if u
            u.cuenta
          else
            (pedido_params[:cuenta_id].present? ? Clientes::Cuenta.find(pedido_params[:cuenta_id].to_i) : nil)
          end
      @pedido = Pedidos::Pedido.new autor: current_user, estado_id: 1
      @pedido.usuario = u if u
      @pedido.cuenta = c if c
      @pedido.fecha = (pedido_params[:fecha].presence&.to_date)
      @pedido.setear_direccion_y_asignar_costo_envio
      @pedido.productos_solicitados.clear
      @pedido.cargando.productos_solicitados.build [{ cantidad: 1 }, { cantidad: 1 }, { cantidad: 1 }]
    end

    def cambiar_cuenta
      authorize! :carga_rapida, Pedidos::Pedido
      @pedido = Pedidos::Pedido.new autor: current_user, estado_id: 1
      @pedido.usuario = nil
      @pedido.cuenta = Clientes::Cuenta.find pedido_params[:cuenta_id].to_i if pedido_params[:cuenta_id].present?
      @pedido.fecha = (pedido_params[:fecha].presence&.to_date)
      @pedido.productos_solicitados.clear
      @pedido.cargando.productos_solicitados.build [{ cantidad: 1 }, { cantidad: 1 }, { cantidad: 1 }]
    end

    def cancelar
      @pedido = Pedidos::Pedido.find params[:id]
      authorize! :cancelar, @pedido
      @pedido.cancelar!
      redirect_to cargas_simples_pedidos_path, notice: "Pedido #{@pedido.codigo} Cancelado correctamente."
    end

    def pedido_params
      params.require(:pedido).permit(:usuario_id, :fecha, :enviar_a_id, :horario_id, :tipo_pedido, :cuenta_id,
                                     :para_id, :direccion_envio, productos_solicitados_attributes: [:producto_id, :cantidad, :_destroy, :id])
    end

    # Merge duplicate producto rows in the submitted form so we never INSERT a second
    # productos_solicitados for a (pedido, producto, menu_diario) tuple that the
    # unique index `index_productos_solicitados_unique_per_pedido` would reject.
    # Sums cantidades into the kept row (existing-id row preferred).
    def dedupe_productos_solicitados_attributes!
      attrs = params.dig(:pedido, :productos_solicitados_attributes)
      return if attrs.blank?

      existing_by_pid = {}
      @pedido.productos_solicitados.each { |ps| existing_by_pid[ps.producto_id] = ps.id } if @pedido&.persisted?

      kept_by_pid = {}
      to_delete = []

      attrs.each do |key, row|
        next if row[:_destroy].to_s.in?(['1', 'true'])

        pid = row[:producto_id].presence&.to_i
        pid = Productos::ProductoSolicitado.where(id: row[:id]).pick(:producto_id) if pid.nil? && row[:id].present?
        next if pid.blank?

        # If this is a new row but an existing PS already covers that producto,
        # retarget it to the existing row's id so it updates instead of inserting.
        if row[:id].blank? && existing_by_pid[pid]
          existing_key = nil
          attrs.each { |k, r| existing_key = k if r[:id].to_i == existing_by_pid[pid] }
          if existing_key
            attrs[existing_key][:cantidad] = attrs[existing_key][:cantidad].to_i + row[:cantidad].to_i
            to_delete << key
            kept_by_pid[pid] ||= existing_key
            next
          else
            row[:id] = existing_by_pid[pid]
          end
        end

        if (target_key = kept_by_pid[pid])
          attrs[target_key][:cantidad] = attrs[target_key][:cantidad].to_i + row[:cantidad].to_i
          to_delete << key
        else
          kept_by_pid[pid] = key
        end
      end

      to_delete.each { |k| attrs.delete(k) }
    end
  end
end
