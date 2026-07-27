module Tiendas
  class TiendasController < ApplicationController
    load_and_authorize_resource except: [:index, :new, :cambiar_local_activo, :cambiar_tienda_activa]

    def index
      authorize! :index, Tienda
      respond_to do |format|
        format.any :html do
          @tiendas = Tiendas::Tienda.paginate(page: params[:page], per_page: 10)
          @tiendas = @tiendas.where(id: tienda_activa) unless current_user.super_admin?
        end
        format.json do
          q = Tiendas::Tienda.where('nombre like ?', "%#{request.parameters[:q]}%")
          render json: q.limit(10).to_json(only: :id, methods: [:nombre, :to_s])
        end
      end
    end

    def new
      @tienda = Tienda.new
      authorize! :new, @tienda
      new_modal_form
    end

    def edit
      authorize! :edit, @tienda
      new_modal_form
    end

    def create
      authorize! :create, @tienda
      @tienda.save
      create_modal_form @tienda, notice: "Tienda <strong>#{@tienda}</strong> creada correctamente.".html_safe
    end

    def update
      authorize! :update, @tienda
      @tienda.assign_attributes tienda_params
      @tienda.save
      create_modal_form @tienda, notice: "Tienda <strong>#{@tienda}</strong> actualizada correctamente.".html_safe
    end

    def destroy
      authorize! :destroy, @tienda
      @tienda.destroy!
      create_modal_form @tienda, notice: "Tienda <strong>#{@tienda}</strong> eliminada correctamente.".html_safe
    end

    def cambiar_tienda_activa
      @tienda = Tienda.find(params[:tienda_activa_id].to_i)

      if current_user.cliente?
        authorize! :cambiar_tienda_activa, @tienda
        return head :forbidden unless current_user.puede_loguearse_en?(@tienda)

        # Cross-tienda PedidoMultiple support: before switching, find the
        # cliente's pendiente pedido in the OLD tienda.
        # - If it has no productos: retag the empty shell to the NEW tienda.
        # - If it has productos AND it's already part of a multi-pedidos group
        #   (pedido_multiple_id present): leave it where it is — the new tienda's
        #   /pedidos/new will create a fresh shell and (via PedidoMultiple
        #   auto-enroll) attach it to the same group.
        # - If it has productos AND it's NOT in a multi group: discard the
        #   productos and retag the now-empty shell to the NEW tienda. We surface
        #   a toast on /pedidos/new explaining what happened and how to opt-in
        #   to multi-tienda multi-pedidos (by picking a second fecha).
        pedido_actual = Pedidos::Pedido.where(usuario_id: current_user.id, autor_id: current_user.id,
                                              estado_id: 1, venta_mostrador: false,
                                              tienda_id: current_user.tienda_activa&.id).last
        descartado_tienda_nombre = nil
        if pedido_actual
          tiene_productos = pedido_actual.productos_solicitados.any?
          en_grupo = pedido_actual.pedido_multiple_id.present?
          if tiene_productos && !en_grupo
            descartado_tienda_nombre = pedido_actual.tienda&.nombre
            pedido_actual.productos_solicitados.destroy_all
          end
          if !tiene_productos || (tiene_productos && !en_grupo)
            updates = { tienda_id: @tienda.id }
            updates[:local_id] = (@tienda.multiple_locales? ? @tienda.local_para_carrito&.id : nil)
            # Reset fecha to proximo_dia_pedido so PedidosController#new (which
            # uses `fecha: dia`) can find this retagged shell after the switch.
            updates[:fecha] = current_user.cuenta&.proximo_dia_pedido || (Date.current + 1.day)
            pedido_actual.update_columns(updates)
          end
        end

        current_user.update_columns(tienda_cliente_id: @tienda.id, visualizando_tienda_id: @tienda.id,
                                    visualizando_local_id: nil)
        new_path = '/pedidos/new'
        new_path += "?carrito_descartado=#{CGI.escape(descartado_tienda_nombre)}" if descartado_tienda_nombre.present?
        respond_to do |format|
          format.html { redirect_to new_path }
          format.json { render json: { ok: true, redirect_url: new_path } }
        end
      else
        authorize! :cambiar_tienda, @tienda
        current_user.update_columns(visualizando_tienda_id: @tienda.id, visualizando_local_id: nil)
        respond_to do |format|
          format.html { redirect_to '/inicio' }
          format.json { render json: { ok: true, redirect_url: '/inicio' } }
        end
      end
    end

    def cambiar_local_activo
      authorize! :cambiar_tienda, tienda_activa
      local_id = params[:local_id].to_i
      if local_id.positive?
        local = Locales::Local.find(local_id)
        raise ActiveRecord::RecordNotFound unless local.tienda_id == tienda_activa.id

        current_user.update_column(:visualizando_local_id, local.id)
      else
        current_user.update_column(:visualizando_local_id, nil)
      end
      render body: nil
    end

    def tienda_params
      params.require(:tienda).permit(:nombre, :active, :descripcion, :carrito_de_compras, :despachos, :venta_mostrador,
                                     :video_ayuda, :color_de_fondo, :domicilio, :telefono, :email,
                                     :stock_notifications_email, :maneja_stock, :color_fondo_logo,
                                     :mensaje_ingreso_a_carrito, :mensaje_bienvenida, :color_de_menu,
                                     :color_barra_filtros, :color_links_hover, :color_links, :dominio,
                                     :color_titulo, :color_barra_superior, :costo_envio_domicilio,
                                     :horarios_de_entrega, :dark_mode_login, :productos_pesables,
                                     :soporta_productos_diarios, :muestra_mas_productos, :muestra_mas_productos_por_categoria, :muestra_menus_del_dia,
                                     :local_atencion_carrito_id, :permitir_login_clientes, documento_ids: [])
    end
  end
end
