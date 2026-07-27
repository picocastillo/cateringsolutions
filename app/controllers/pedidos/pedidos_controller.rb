module Pedidos
  class PedidosController < ApplicationController
    require 'mercadopago'
    before_action :load_pedido_with_includes, except: [:index]
    before_action :disable_turbolinks_cache, except: [:index]
    rescue_from ActiveRecord::RecordNotFound, with: :record_not_found

    def index
      authorize! :index, Pedido
      respond_to do |format|
        format.any :html, :js do
          @filtro_abierto = params[:show_filtro].present?
          @query = PedidosQuery.new query_params
          @query.fecha_desde = Time.zone.today if params[:q].blank? && @query.fecha_desde.blank? && !current_user.cliente?
          # Hide pedidos pendientes (estado_id 1) from the index unless the user
          # is explicitly filtering for them.
          @query.no_pendientes = true if @query.estado_id.blank?
          @pedidos = @query.page(params[:page]).per_page(10)
        end
        format.xls do
          validar_rango_fechas_exportacion!(380, label: '12 meses')
          export_in_background ResumenPedidosExporter
        end
      end
    end

    def footer_aggregates
      authorize! :index, Pedido
      query = PedidosQuery.new query_params
      query.fecha_desde = Time.zone.today if params[:q].blank? && query.fecha_desde.blank? && !current_user.cliente?
      query.no_pendientes = true if query.estado_id.blank?
      render json: query.footer_aggregates
    end

    def show
      @pedido = Pedidos::Pedido.find params[:id].to_i
      authorize! :show, @pedido

      # Multi-pedido: redirect pending grouped pedidos to the group resumen
      if @pedido.pendiente? && @pedido.en_grupo? && @pedido.pedido_multiple.pedidos.many?
        redirect_to resumen_pedido_multipl_path(@pedido.pedido_multiple)
        return
      end

      # Only check stock and show warnings for pending pedidos
      @productos_sin_stock = []
      if @pedido.pendiente?
        # Check stock availability for products with stock control enabled
        @pedido.productos_solicitados.each do |ps|
          next unless ps.producto.categoria&.stock_activo

          stock_disponible = ps.producto.stock_actual(@pedido.local&.id)
          if stock_disponible < 1
            @productos_sin_stock << { producto: ps.producto, solicitado: ps.cantidad, disponible: 0 }
          elsif ps.cantidad > stock_disponible
            @productos_sin_stock << { producto: ps.producto, solicitado: ps.cantidad, disponible: stock_disponible }
          end
        end
      else
        # Clear stock warnings for non-pending pedidos
        flash.discard(:warning)
        flash.discard(:productos_sin_stock)
      end

      if @productos_sin_stock.any?
        flash.now[:warning] =
          '⚠️ Algunos productos en tu carrito están sin stock o tienen stock insuficiente. Por favor revisa las cantidades antes de finalizar.'
      end

      return if params[:external_reference].blank?
      return unless params[:status] != 'approved'

      flash.now[:error] = "El pago del #{@pedido} no se ha completado. Intente nuevamente en unos instantes."
    end

    def comprar
      @pedido = Pedidos::Pedido.find params[:pedido_id].to_i
      authorize! :create, @pedido

      # Multi-pedido: go to group resumen instead of single-pedido checkout
      if @pedido.en_grupo? && @pedido.pedido_multiple.pedidos.many?
        redirect_to resumen_pedido_multipl_path(@pedido.pedido_multiple)
        return
      end

      # Check stock availability for pending pedidos
      @productos_sin_stock = []
      if @pedido.pendiente?
        @pedido.productos_solicitados.each do |ps|
          next unless ps.producto.categoria&.stock_activo

          stock_disponible = ps.producto.stock_actual(@pedido.local&.id)
          if stock_disponible < 1
            @productos_sin_stock << { producto: ps.producto, solicitado: ps.cantidad, disponible: 0 }
          elsif ps.cantidad > stock_disponible
            @productos_sin_stock << { producto: ps.producto, solicitado: ps.cantidad, disponible: stock_disponible }
          end
        end

        if @productos_sin_stock.any?
          flash.now[:warning] =
            '⚠️ Algunos productos en tu carrito están sin stock o tienen stock insuficiente. Por favor revisa las cantidades antes de finalizar.'
        end
      end

      @pedido.setear_direccion_y_asignar_costo_envio
      render :show
    end

    def opciones
      # Legacy action — opciones page was merged into comprar. The route now
      # 301-redirects at the routes.rb level, so this action should never run,
      # but we keep it as a defensive fallback.
      redirect_to pedido_comprar_path(params[:pedido_id]), status: :moved_permanently
    end

    def generar_pago_ml
      authorize! :create, @pedido
      return unless @pedido.estado == :pendiente && !@pedido.cobrado?

      # Validate option selections (turno, enviar_a, horario) before creating the
      # MercadoPago preference. If any required option is missing, render a JS
      # response that disables the MP button + shows an inline hint instead of
      # auto-opening the modal. Logic ported from the legacy finalizar_opciones.
      @validation_errors = []
      cliente = @pedido.cuenta.cliente

      if tienda_activa.carrito_de_compras? && cliente.turnos_activos.any?
        if @pedido.turno_entrega_id.blank?
          @validation_errors << "Seleccioná un 'Turno de Entrega' para continuar."
        elsif !cliente.tiene_turno?(@pedido.turno_entrega_id)
          @validation_errors << 'El turno de entrega seleccionado no está disponible para tu cuenta.'
        end
      end

      if !tienda_activa.carrito_de_compras? && cliente.horarios_de_entrega? &&
         tienda_activa.horarios_de_entrega? && @pedido.horario_id.blank?
        @validation_errors << "Seleccioná un 'Horario' de envío para continuar."
      end

      if !@pedido.pedido_para_empresa && cliente.usuario_puede_elegir_cuenta && @pedido.enviar_a_id.blank?
        @validation_errors << 'Completá el campo Enviar A para definir el destino del envío.'
      end

      @validation_errors << 'Ingresá la dirección de envío a domicilio.' if @pedido.envio_a_domicilio && @pedido.direccion_envio.blank?

      if @validation_errors.any?
        respond_to do |format|
          format.js { render :generar_pago_ml }
        end
        return
      end

      # Check stock availability before generating payment
      # Stocks are already eager-loaded via load_pedido_with_includes
      productos_sin_stock = []
      @pedido.productos_solicitados.each do |ps|
        next unless ps.producto.categoria&.stock_activo

        stock_disponible = ps.producto.stock_actual(@pedido.local&.id)
        if stock_disponible < 1
          productos_sin_stock << { nombre: ps.producto.nombre, solicitado: ps.cantidad, disponible: 0 }
        elsif ps.cantidad > stock_disponible
          productos_sin_stock << { nombre: ps.producto.nombre, solicitado: ps.cantidad, disponible: stock_disponible }
        end
      end

      # If there are stock issues, show alert and redirect to comprar page
      if productos_sin_stock.any?
        respond_to do |format|
          format.js do
            mensaje = "⚠️ Stock insuficiente:\n\n"
            productos_sin_stock.each do |p|
              mensaje += "• #{p[:nombre]}: solicitaste #{p[:solicitado]}, disponibles #{p[:disponible]}\n"
            end
            mensaje += "\nPor favor ajusta las cantidades antes de pagar.\n"
            escaped = mensaje.gsub("'", "\\\\'")
            render js: "if(confirm('#{escaped}')) { " \
                       "window.location.href = '#{edit_pedido_path(@pedido)}'; } " \
                       "else { window.location.href = '#{pedido_comprar_path(@pedido)}'; }"
          end
        end
        return
      end

      # Check purchase limit before generating payment
      limite_msg = @pedido.mensaje_limite_compra_excedido
      if limite_msg
        respond_to do |format|
          format.js do
            escaped = limite_msg.gsub("'", "\\\\'")
            render js: "alert('⚠️ #{escaped}'); window.location.href = '#{pedido_comprar_path(@pedido)}';"
          end
        end
        return
      end

      respond_to do |format|
        format.any :js do
          mp         = Mercadopago::SDK.new(Rails.application.secrets.mp)
          cupon      = @pedido.cupon
          cupon_code = cupon&.codigo
          has_cupon  = cupon.present?

          its = @pedido.productos_solicitados.map do |x|
            title = x.nombre_carrito
            title = "#{title} C#{cupon_code}" if has_cupon && x.tiene_descuento?
            {
              title: title,
              unit_price: x.precio_efectivo.to_f,
              quantity: x.cantidad,
              picture_url: imagen_url(x),
              description: x.producto.descripcion,
              category_id: x.producto.categoria.nombre,
              currency_id: 'ARS'
            }
          end
          if @pedido.envio_a_domicilio && @pedido.costo_envio_domicilio.positive?
            its << { title: 'Envío a domicilio',
                     unit_price: @pedido.costo_envio_domicilio.to_f,
                     quantity: 1,
                     currency_id: 'ARS' }
          end
          payer =
            {
              name: @pedido.usuario ? @pedido.usuario.to_s : @pedido.cuenta.to_s,
              email: @pedido.usuario ? @pedido.usuario.email : @pedido.cuenta.cliente.email,
              identification: {
                type: 'DNI',
                number: @pedido.usuario ? @pedido.usuario.dni : @pedido.cuenta.cliente.cuit
              }
            }
          preference_data = {
            items: its,
            payer: payer,
            back_urls: {
              success: confirmation_url(@pedido.confirmation_token, pedido_id: @pedido.id),
              failure: pedido_url(@pedido),
              pending: pedido_url(@pedido)
            },
            payment_methods: {
              excluded_payment_types: [
                {
                  id: 'ticket'
                }
              ]
            },
            statement_descriptor: 'COBRO_ML_WEB_CS',
            external_reference: "#{@pedido.id}-#{current_user.id}",
            binary_mode: true
          }
          Rails.logger.info 'MERCADOPAGOOOOOOOOOOOOO'
          Rails.logger.info preference_data
          preference_response = mp.preference.create(preference_data)
          Rails.logger.info 'RESPONSEEEE'
          preference = preference_response[:response]
          Rails.logger.info 'FULL RESPONSEEEE'
          Rails.logger.info preference_response
          Rails.logger.info preference
          Rails.logger.info preference['id']
          @preference_id = preference['id']
        end
      end
    end

    def finalizar
      authorize! :aceptar, @pedido
      errores = []

      # Check stock availability FIRST before any other validation
      productos_sin_stock = []
      @pedido.productos_solicitados.each do |ps|
        next unless ps.producto.categoria&.stock_activo

        stock_disponible = ps.producto.stock_actual(@pedido.local&.id)
        if stock_disponible < 1
          productos_sin_stock << { producto: ps.producto, solicitado: ps.cantidad, disponible: 0 }
        elsif ps.cantidad > stock_disponible
          productos_sin_stock << { producto: ps.producto, solicitado: ps.cantidad, disponible: stock_disponible }
        end
      end

      # If there are stock issues, redirect back to checkout with details
      if productos_sin_stock.any?
        redirect_to pedido_comprar_path(@pedido),
                    flash: {
                      warning: '⚠️ Algunos productos en tu carrito están sin stock o tienen stock ' \
                               'insuficiente. Por favor revisa las cantidades antes de finalizar.',
                      productos_sin_stock: productos_sin_stock
                    }
        return
      end

      # Check purchase limit before accepting
      limite_msg = @pedido.mensaje_limite_compra_excedido
      if limite_msg
        redirect_to pedido_comprar_path(@pedido), flash: { error: "⚠️ #{limite_msg}" }
        return
      end

      if !tienda_activa.carrito_de_compras? && @pedido.cuenta.cliente.horarios_de_entrega? && tienda_activa.horarios_de_entrega? &&
         params[:horario_id].blank?
        errores << "Debe selecionar algún 'Horario' de envío antes de Finalizar la Compra."
      end
      if !@pedido.pedido_para_empresa && params[:enviar_a_id].blank? && @pedido.cuenta.cliente.usuario_puede_elegir_cuenta
        errores << 'Debe completar el campo Enviar A para definir el destino del Envío antes de Finalizar la Compra.'
      end

      if errores.present?
        redirect_to @pedido, flash: { error: errores.join('. ') }
      else
        if params[:enviar_a_id].present? &&
           (@pedido.cuenta.cliente.permitir_envios_a_domicilio || @pedido.cuenta.cliente.usuario_puede_elegir_cuenta)
          @pedido.enviar_a_id = params[:enviar_a_id]
          @pedido.direccion_envio = params[:direccion]
        end
        if params[:horario_id].present? && !tienda_activa.carrito_de_compras? &&
           @pedido.cuenta.cliente.horarios_de_entrega? &&
           tienda_activa.horarios_de_entrega?
          @pedido.horario_id = params[:horario_id].to_i
        end

        if params[:cupon_codigo].present? && @pedido.cupon.blank?
          cupon = Cupones::Cupon.buscar_vigente(params[:cupon_codigo], tienda_activa)
          @pedido.aplicar_cupon!(cupon) if cupon
        end

        @pedido.aceptar(current_user)

        if @pedido.save && errores.blank?
          # Reduce stock immediately after accepting for cuenta_corriente customers
          # This ensures stock is deducted when customer finalizes order, not when admin confirms
          @pedido.reducir_stock_si_necesario

          c = @pedido.usuario ? @pedido.usuario.cuenta : @pedido.cuenta
          hce = c.hora_corte_efectiva
          fecha = hce == '00:00' ? (@pedido.fecha - 1.day) : @pedido.fecha
          hc = hce == '00:00' ? '23:59' : hce
          if @pedido.usuario && @pedido.envio_a_domicilio
            @pedido.usuario.update_column :direccion_envio,
                                          @pedido.direccion_envio
          end
          fecha_label = I18n.l(fecha, format: '%A %-d').capitalize
          msg = "Pedido ##{@pedido.codigo} exitoso! El mismo fue <strong><i>Aceptado</i></strong> y podrás modificarlo hasta las #{hc}hs del #{fecha_label}. " \
                'De modificarlo, recordá avanzar a esta pantalla nuevamente y <strong><i>Finalizarlo</i></strong>. ' \
                'De lo contrario, quedará <strong><i>pendiente</i></strong> en el carrito y no será despachado.'
          redirect_to @pedido, flash: { notice_long: msg }
        else
          redirect_to @pedido,
                      flash: {
                        error: "#{@pedido.errors.full_messages.to_sentence}.#{errores.join} Por favor Edite el pedido."
                      }
        end
      end
    end

    def aplicar_cupon
      authorize! :edit, @pedido
      respond_to do |format|
        format.js do
          codigo = params[:cupon_codigo].to_s.strip
          cupon = Cupones::Cupon.buscar_vigente(codigo, tienda_activa)
          if !@pedido.pendiente?
            @cupon_error = 'Solo se puede aplicar un cupón a pedidos pendientes.'
          elsif cupon
            @pedido.aplicar_cupon!(cupon)
            @pedido.reload
            @cupon_ok = true
          else
            @cupon_error = 'Cupón inválido, vencido o ya utilizado.'
          end
        end
      end
    end

    def quitar_cupon
      authorize! :edit, @pedido
      respond_to do |format|
        format.js do
          @pedido.quitar_cupon! if @pedido.pendiente? && @pedido.cupon.present?
          @pedido.reload
        end
      end
    end

    def importar
      authorize! :import, Pedidos::Pedido
      raise ErrorAplicacion, 'Está intentando importar pedidos de otro dominio.' if request.domain(2) != tienda_activa.dominio && !Rails.env.development?

      cliente = Clientes::Cliente.where(id: params[:cliente_id].to_i).first if params[:cliente_id].to_i.positive?
      f = params[:fecha].to_date if params[:fecha]
      if params[:proceso] && params[:proceso][:adjunto]&.tempfile && cliente && f
        # Merge cliente_id and fecha into proceso params so the background importer can access them
        proceso_hash = (request.parameters.delete(:proceso) || {}).to_h.symbolize_keys
        proceso_hash[:autor] = current_user
        proceso_hash[:tienda] = tienda_activa
        proceso_hash[:importar] = true
        proceso_hash[:params] = { 'cliente_id' => cliente.id, 'fecha' => f.to_s }
        proceso = Pedidos::PedidosImporter.new(proceso_hash)
        raise ErrorAplicacion, proceso.errors.full_messages unless proceso.save

        Infraestructura::Procesos::LanzarProcesoJob.perform_later proceso
        redirect_to pedidos_path,
                    notice: "La importación se procesará en segundo plano. <a href='#{procesos_path}'>Ver progreso</a>".html_safe
      else
        flash[:error] = 'Debe seleccionar Cuenta existente y adjuntar el XLS'
        redirect_to pedidos_path
      end
    end

    def new
      authorize! :new, Pedido
      dia = current_user.cliente? ? current_user.cuenta.proximo_dia_pedido : 1.day.since
      @pedido = if current_user.cliente?
                  # Step 6 of shared-clientes migration: cliente users may have a
                  # cliente shared across multiple tiendas, so the cart must be
                  # scoped to tienda_activa (driven by tienda_cliente_id), not the
                  # legacy cliente.tienda_id column.
                  # Cross-tienda switch: cambiar_tienda_activa resets the empty
                  # shell's fecha to proximo_dia_pedido before redirecting here,
                  # so the `fecha: dia` filter always finds it. Using the date
                  # filter avoids picking up unrelated pending pedidos created for
                  # far-future dates (e.g. cupon test fixtures).
                  Pedido.where(usuario_id: current_user, autor_id: current_user, estado_id: 1,
                               tienda_id: tienda_activa.id, fecha: dia,
                               venta_mostrador: false).last ||
                    Pedido.new(fecha: dia, usuario: current_user,
                               autor: current_user,
                               tienda_id: tienda_activa.id)
                else
                  Pedido.where(autor_id: current_user, estado_id: 1, tienda_id: tienda_activa.id, venta_mostrador: false,
                               fecha: dia).last || Pedido.new(autor: current_user, estado_id: 1,
                                                              fecha: dia, tienda_id: tienda_activa.id)
                end
      @pedido.local ||= tienda_activa.local_para_carrito if tienda_activa.multiple_locales?
      @pedido.save! if @pedido.new_record?

      # Cross-tienda PedidoMultiple support: if the user already has an open
      # group (with at least one pendiente child in any tienda) and the
      # current pedido isn't part of a group yet, enroll it. This keeps the
      # multi-pedido cart visible and editable from any tienda the user is
      # browsing.
      #
      # SECURITY (Bug B — incident 2026-05-17 PM 78): the lookup MUST be
      # scoped to the current usuario_id. The previous cuenta_id fallback
      # let a different user in the same cuenta auto-join another user's
      # open group, which combined with the Vaciar Carrito bug caused user
      # 7388 to destroy user 6180's paid pedidos. Never share a PM across
      # users at the cliente surface.
      if @pedido.pedido_multiple_id.nil?
        grupo_abierto = if current_user.cliente?
                          Pedidos::PedidoMultiple.abiertos.where(usuario_id: current_user.id).order(:id).last
                        else
                          Pedidos::PedidoMultiple.abiertos
                                                 .joins(:pedidos)
                                                 .where(pedidos: { autor_id: current_user.id })
                                                 .order(:id)
                                                 .last
                        end
        if grupo_abierto && grupo_abierto.pedidos.count < Pedidos::PedidoMultiple::MAX_PEDIDOS
          @pedido.update_column(:pedido_multiple_id, grupo_abierto.id)

          # Bug 1: when the new shell would land on a fecha already taken by
          # another sibling in the group (typical cross-tienda case where
          # cuenta.proximo_dia_pedido returns the same day as an existing
          # pedido in another tienda), advance to the next valid weekday that
          # is NOT already in the group. Keeps the badge strip clean and
          # avoids the "duplicate fecha" warning UI.
          fechas_ocupadas = grupo_abierto.pedidos.where.not(id: @pedido.id).pluck(:fecha).compact
          if @pedido.fecha && fechas_ocupadas.include?(@pedido.fecha)
            nueva_fecha = @pedido.fecha + 1.day
            nueva_fecha += 1.day while nueva_fecha.saturday? || nueva_fecha.sunday? || fechas_ocupadas.include?(nueva_fecha)
            @pedido.update_column(:fecha, nueva_fecha)
          end
        end
      end

      redirect_to(edit_pedido_path(@pedido, carrito_descartado: params[:carrito_descartado].presence))
    end

    def cambiar_cuenta
      if pedido_params[:usuario_id].present?
        u = if current_user.cliente
              if current_user.cumple_rol?(:administrador_empresa)
                if pedido_params[:usuario_id].present?
                  cuentas_ids = current_user.cuenta.cliente.cuentas.map(&:id)
                  Usuarios::Usuario.where(cuenta_id: cuentas_ids).find(pedido_params[:usuario_id].to_i)
                end
              else
                current_user
              end
            else
              Usuarios::Usuario.find(pedido_params[:usuario_id].to_i)
            end
        @pedido.usuario = u
        # When a usuario is assigned, the cuenta must follow the usuario's own
        # cuenta. The form serializes the whole form on every change, so a stale
        # cuenta_id from a different cliente can ride along — ignore it here to
        # avoid ever persisting a cross-cliente usuario/cuenta pair (which would
        # later 500 the cart in asignar_cuenta).
        @pedido.cuenta = u&.cuenta
      elsif pedido_params.key?(:usuario_id)
        @pedido.usuario = nil
        @pedido.cuenta = nil
      end
      authorize! :edit, @pedido
      if pedido_params[:usuario_id].blank? && pedido_params[:cuenta_id].present?
        @pedido.cuenta = Clientes::Cuenta.joins(cliente: :tiendas).where(tiendas: { id: tienda_activa.id }).distinct.find pedido_params[:cuenta_id].to_i
      elsif pedido_params.key?(:cuenta_id) && pedido_params[:cuenta_id].blank? && pedido_params[:usuario_id].blank?
        # Only nil the cuenta when there is no usuario being assigned. When tipo_pedido=1
        # the cuenta field is hidden and submits blank, but the cuenta derives from the
        # usuario — clearing it here would make cuenta_id_changed? = true and break the
        # fecha-change → sibling-creation path.
        @pedido.cuenta = nil
      end
      @pedido.fecha = pedido_params[:fecha].present? ? pedido_params[:fecha].to_date : @pedido.cuenta&.cliente&.dia_filtro
      @resaltar_menues = @pedido.fecha_changed?

      # When only fecha changed and the pedido already has products, create a new sibling in
      # the grupo instead of wiping the current pedido. The user is navigated to the new sibling.
      if @resaltar_menues && !@pedido.cuenta_id_changed? && !@pedido.usuario_id_changed? &&
         @pedido.productos_solicitados.present?
        nueva_fecha = @pedido.fecha
        grupo = @pedido.pedido_multiple || Pedidos::PedidoMultiple.create!(usuario: current_user, cuenta: @pedido.cuenta)
        @pedido.update_column(:pedido_multiple_id, grupo.id) unless @pedido.pedido_multiple_id
        grupo.reload

        existing = grupo.pedidos.find_by(fecha: nueva_fecha, tienda: @pedido.tienda)
        if existing && existing.id != @pedido.id
          @redirigir_a = edit_pedido_path(existing)
        elsif grupo.pedidos.count >= Pedidos::PedidoMultiple::MAX_PEDIDOS
          @error_grupo = "Ya alcanzaste el máximo de #{Pedidos::PedidoMultiple::MAX_PEDIDOS} pedidos en el grupo."
        else
          # Pick the next valid (weekday, not already in group) date >= proximo_dia_pedido.
          # This avoids passing no_validar_fecha: true with a potentially past fecha.
          fechas_ocupadas = grupo.pedidos.pluck(:fecha).compact
          proximo = @pedido.cuenta&.proximo_dia_pedido || (Date.current + 1)
          fecha_sibling = [nueva_fecha, proximo].max
          fecha_sibling += 1.day while fecha_sibling.saturday? || fecha_sibling.sunday? || fechas_ocupadas.include?(fecha_sibling)

          nuevo = Pedidos::Pedido.create!(
            tienda: @pedido.tienda,
            autor: current_user,
            usuario: @pedido.usuario,
            cuenta: @pedido.cuenta,
            estado_id: 1,
            fecha: fecha_sibling,
            local: @pedido.local || current_user.local_activo,
            pedido_multiple_id: grupo.id
          )
          @redirigir_a = edit_pedido_path(nuevo)
        end
        @pedido.reload
        return render :cambiar_cuenta
      end

      if @pedido.cuenta_id_changed? || @pedido.usuario_id_changed? || @resaltar_menues
        @advertir_limpieza = @pedido.productos_solicitados.present?
        @pedido.quitar_cupon! if @pedido.cupon.present?
        @pedido.productos_solicitados.delete_all
      end
      # Consolidate all column updates into a single UPDATE query
      updates = {}
      updates[:fecha] = @pedido.fecha if @resaltar_menues
      if @pedido.usuario_id_changed?
        updates[:pedido_para_empresa] = false
        updates[:usuario_id] = @pedido.usuario_id
        updates[:cuenta_id] = @pedido.usuario&.cuenta_id
      end
      if @pedido.cuenta_id_changed?
        updates[:cuenta_id] = @pedido.cuenta&.id
        updates[:pedido_para_empresa] = @pedido.cuenta.present? unless updates.key?(:pedido_para_empresa)
        updates[:usuario_id] = nil unless updates.key?(:usuario_id)
      end
      Pedidos::Pedido.where(id: @pedido.id).update_all(updates) if updates.any?
      @pedido.reload
      cargar_productos
    end

    def late_pannels
      @pedido = Pedidos::Pedido.find params[:id]
      authorize! :edit, @pedido
      cats = params[:cats].split(',').map(&:to_i)
      cargar = cats.shift(3)
      @cats_restantes = cats
      cargar_productos cargar
    end

    def productos_diarios_panel
      authorize! :edit, @pedido
      @cuenta_activa = @pedido.cuenta || @pedido.usuario&.cuenta
      respond_to do |format|
        format.js
      end
    end

    def actualizar_producto
      authorize! :edit, @pedido
      @suma = true
      @actualizar_menu_pedido = true if params[:refresh].present?
      producto_id = params[:productoid].to_i
      nueva_cantidad = params[:cantidad].to_i

      with_pedido_upsert_lock(@pedido.id) do
        @pedido.productos_solicitados.reload
        @ps = @pedido.productos_solicitados.find { |x| x.producto_id == producto_id }
        producto = @ps&.producto || @pedido.productos_solicitados.map(&:producto).find { |p| p.id == producto_id } || Productos::Producto.find(producto_id)

        if producto.categoria&.stock_activo && nueva_cantidad.positive?
          stock_disponible = producto.stock_actual(@pedido.local&.id)
          if stock_disponible < nueva_cantidad
            @stock_error = true
            @stock_error_producto = producto
            @stock_error_disponible = stock_disponible
            @stock_error_solicitado = nueva_cantidad
            @stock_error_message = stock_disponible.zero? ? 'Sin stock disponible' : "Stock insuficiente. Disponible: #{stock_disponible}"
            next
          end
        end

        if @ps
          @suma = false if nueva_cantidad < @ps.cantidad
          @ps.cantidad = nueva_cantidad
        else
          menu_diario = params[:menudiarioid].presence&.to_i
          @ps = Productos::ProductoSolicitado.new(
            pedido: @pedido, cantidad: nueva_cantidad,
            producto_id: producto_id, menu_diario_id: menu_diario
          )
          @pedido.productos_solicitados << @ps
        end
        if @ps.cantidad.zero?
          @eps = @ps.to_s
          @ps.destroy!
          @pedido.productos_solicitados.reload
        end
        @pedido.save

        if @pedido.cupon.present?
          result = @pedido.reaplicar_cupon!
          @cupon_expirado = true if result == :expired
        end
      end
      return if @stock_error

      @pedido_pendiente = @pedido
      @pedido.flush_cache(:importe_total)
      @limite_error_message = @pedido.mensaje_limite_compra_excedido
    end

    def cambiar_categoria
      authorize! :edit, @pedido
      @timelong = Time.current.to_ms
      @pedido.viendo_categorias = (params[:viendo_categoria_ids].presence)
      @pedido.busqueda = (params[:busqueda].presence)
      @pedido.save
      cargar_productos
    end

    def actualizar_desde_carrito
      authorize! :edit, @pedido
      redireccionar = false
      if @pedido.cuenta && @pedido.fecha && @pedido.fecha < @pedido.cuenta.proximo_dia_pedido
        redireccionar = true
        @pedido.fecha = @pedido.cuenta.proximo_dia_pedido
      end
      if params[:vaciar_carrito].present? || redireccionar
        vaciar_carrito_pendiente!
        @vaciar_carrito = true
        if redireccionar
          redirect_to edit_pedido_path(@pedido, notice: 'Fecha vencida e inválida se ha vaciado el carrito.')
        else
          @pedido_pendiente = @pedido
          cargar_productos
        end
      else
        @ps = @pedido.productos_solicitados.find { |x| x.producto_id == params[:productoid].to_i }
        if @ps
          @ps.cantidad = params[:cantidad].to_i
          if @ps.cantidad.zero?
            @ps.destroy!
            @pedido.productos_solicitados.reload
          end
        end
        @pedido.save
      end

      # Re-apply cupon discount after cart changes
      if @pedido.cupon.present?
        result = @pedido.reaplicar_cupon!
        @cupon_expirado = true if result == :expired
      end

      # Check purchase limit after cart update
      @pedido.flush_cache(:importe_total)
    end

    def edit
      authorize! :edit, @pedido
      if @pedido.estado_id == 1
        @pedido_pendiente = @pedido
        if current_user.cliente? && @pedido.fecha && @pedido.fecha < current_user.cuenta.proximo_dia_pedido
          @pedido.fecha = current_user.cuenta.proximo_dia_pedido
        end
      end
      # Pre-load data used by views to avoid view-level queries
      if current_user.operador? || current_user.cumple_rol?(:administrador_empresa)
        @cuentas = Clientes::Cuenta.joins(cliente: :tiendas).where(tiendas: { id: tienda_activa.id }).active.distinct
        # Always include the pedido's current cuenta even if the tienda link was severed
        if @pedido.cuenta_id && @cuentas.none? { |c| c.id == @pedido.cuenta_id }
          extra = Clientes::Cuenta.active.find_by(id: @pedido.cuenta_id)
          @cuentas = @cuentas.to_a.push(extra).compact
        end
        if current_user.cliente? && current_user.cumple_rol?(:administrador_empresa)
          @cuentas = @cuentas.where(cuentas: { id: current_user.cuenta.cliente.cuentas.map(&:id) })
        end
      end
      cargar_productos_shell
    end

    def update
      authorize! :edit, @pedido
      begin
        allowed = [:turno_entrega_id, :enviar_a_id, :direccion_envio, :horario_id]
        if @pedido.update(pedido_params.slice(*allowed))
          respond_to do |format|
            format.json { render json: { success: true } }
            format.html { redirect_to edit_pedido_path(@pedido) }
          end
        else
          respond_to do |format|
            format.json { render json: { success: false, errors: @pedido.errors }, status: :unprocessable_entity }
            format.html { redirect_to edit_pedido_path(@pedido), alert: 'Error al actualizar' }
          end
        end
      rescue ActiveRecord::InvalidForeignKey
        respond_to do |format|
          format.json do
            render json: { success: false, error: 'Turno de entrega inválido' }, status: :unprocessable_entity
          end
          format.html { redirect_to edit_pedido_path(@pedido), alert: 'Turno de entrega inválido' }
        end
      end
    end

    def re_edit
      authorize! :re_edit, @pedido
      current_user.pedido_pendiente.destroy if current_user.pedido_pendiente && (current_user.pedido_pendiente != @pedido)
      @pedido.update_column :estado_id, 1
      redirect_to(edit_pedido_path(@pedido))
    end

    def record_not_found
      redirect_to new_pedido_path
    end

    def destroy
      authorize! :destroy, @pedido
      nombre = @pedido.pendiente? ? '' : @pedido.to_s
      @pedido.destroy!
      redirect_to pedidos_path, notice: "Pedido #{nombre} eliminado correctamente."
    end

    def cancelar
      @pedido = Pedidos::Pedido.find params[:id]
      authorize! :cancelar, @pedido
      @pedido.cancelar!
      redirect_to pedidos_path, notice: "Pedido #{@pedido.codigo} Cancelado correctamente."
    end

    # POST /pedidos/:id/agregar_al_multiple
    # Called when the user presses + to add another day to a multi-pedido group.
    # If the current pedido has products and a date it is enrolled in (or creates) a PedidoMultiple,
    # then a new empty sibling pedido is created and the user is redirected to edit it.
    def agregar_al_multiple
      authorize! :edit, @pedido

      unless @pedido.productos_solicitados.present? && @pedido.fecha.present?
        redirect_to edit_pedido_path(@pedido), alert: 'Cargá al menos un producto y elegí una fecha antes de agregar otro día.'
        return
      end

      grupo = @pedido.pedido_multiple ||
              Pedidos::PedidoMultiple.create!(usuario: current_user, cuenta: @pedido.cuenta)

      if grupo.pedidos.count >= Pedidos::PedidoMultiple::MAX_PEDIDOS
        redirect_to edit_pedido_path(@pedido), alert: "Ya alcanzaste el máximo de #{Pedidos::PedidoMultiple::MAX_PEDIDOS} pedidos en el grupo."
        return
      end

      @pedido.update!(pedido_multiple_id: grupo.id) unless @pedido.pedido_multiple_id

      nueva_fecha = params[:nueva_fecha].present? ? Date.parse(params[:nueva_fecha]) : nil

      # Resolve the tienda for the new sibling pedido.
      # The form sends nueva_tienda_id when the cliente has access to multiple tiendas.
      # Fall back to tienda_activa when the param is absent (single-tienda clientes).
      nueva_tienda = if params[:nueva_tienda_id].present?
                       t = Tiendas::Tienda.find_by(id: params[:nueva_tienda_id])
                       unless t && current_user.puede_loguearse_en?(t)
                         redirect_to edit_pedido_path(@pedido), alert: 'No tenés acceso a esa tienda.'
                         return
                       end
                       t
                     else
                       current_user.tienda_activa
                     end

      if nueva_fecha && grupo.pedidos.exists?(fecha: nueva_fecha, tienda: nueva_tienda)
        redirect_to edit_pedido_path(@pedido), alert: 'Ya existe un pedido para esa fecha y tienda en el grupo.'
        return
      end

      # For cross-tienda pedidos the cuenta must belong to the nueva_tienda.
      # Try to find a matching cuenta; fall back to the pedido's cuenta if it's shared.
      cuenta_para_nuevo = begin
        Clientes::Cuenta.joins(cliente: :tiendas)
                        .where(tiendas: { id: nueva_tienda.id })
                        .where(cliente_id: @pedido.cuenta&.cliente_id)
                        .first || @pedido.cuenta
      rescue StandardError
        @pedido.cuenta
      end

      nuevo = Pedidos::Pedido.create!(
        tienda: nueva_tienda,
        autor: current_user,
        usuario: @pedido.usuario,
        cuenta: cuenta_para_nuevo,
        estado_id: 1,
        fecha: nueva_fecha,
        pedido_multiple_id: grupo.id
      )

      redirect_to edit_pedido_path(nuevo), notice: 'Pedido nuevo agregado al grupo.'
    end

    # DELETE /pedidos/:id/salir_del_multiple
    # Removes this pedido from its group and destroys it.
    # If the group ends up with 1 remaining member that member is also ungrouped and the group is destroyed.
    def salir_del_multiple
      authorize! :edit, @pedido
      authorize! :destroy, @pedido
      grupo = @pedido.pedido_multiple

      # Unlink first so the grupo reload below doesn't count this pedido
      @pedido.update_column(:pedido_multiple_id, nil)

      miembros = nil
      if grupo
        miembros = grupo.pedidos.reload
        # SECURITY (Bug A): only auto-ungroup the lone survivor when it
        # belongs to the same user and is still a pendiente shell — never
        # rewrite pedido_multiple_id or destroy the group around someone
        # else's in-flight or paid pedido.
        if miembros.count <= 1
          superviviente = miembros.first
          if superviviente.nil? ||
             (superviviente.autor_id == current_user.id && superviviente.estado_id == 1 &&
              !superviviente.facturado? && !superviviente.cobrado? && superviviente.pagos_electronicos.empty?)
            superviviente&.update_column(:pedido_multiple_id, nil)
            grupo.destroy!
          end
        end
      end

      # Destroy the pedido itself (it was a sibling created just for the group)
      redirect_pedido = miembros&.first
      @pedido.destroy!

      if redirect_pedido
        redirect_to edit_pedido_path(redirect_pedido), notice: 'Pedido eliminado.'
      else
        redirect_to new_pedido_path, notice: 'Pedido eliminado.'
      end
    end

    def pedido_params
      params.require(:pedido).permit(:tipo_pedido, :cuenta_id, :usuario_id, :fecha, :observaciones_cliente,
                                     :observaciones_chef, :id, :viendo_categoria_ids, :busqueda, :turno_entrega_id,
                                     :enviar_a_id, :direccion_envio, :horario_id)
    end

    private

    def vaciar_carrito_pendiente!
      Pedidos::Pedido.transaction do
        if @pedido.en_grupo?
          grupo = @pedido.pedido_multiple

          # SECURITY (Bug A — incident 2026-05-17 PM 78, MP 159008984833 $14,820):
          # NEVER destroy sibling pedidos that the current user does not own,
          # and NEVER destroy a sibling that is past the pendiente cart stage
          # or already carries billing/payment value. The only siblings we are
          # allowed to nuke from a "Vaciar Carrito" click are pendiente shells
          # authored by the same user that has the cart open.
          siblings = grupo.pedidos.where.not(id: @pedido.id)
          destroyable = siblings.where(autor_id: current_user.id, estado_id: 1, facturado: [false, nil],
                                       cobrado: [false, nil]).where.missing(:pagos_electronicos)
          destroyable.find_each(&:destroy!)

          resetear_pedido_vaciado!(@pedido, pedido_multiple_id: nil)

          # Only destroy the group if no other live pedidos remain. Leaves
          # any siblings owned by other users (or already paid/billed) safely
          # attached to the group.
          grupo.reload
          grupo.destroy! if grupo.persisted? && grupo.pedidos.empty?
        else
          resetear_pedido_vaciado!(@pedido)
        end
      end
      @pedido.reload
    end

    def resetear_pedido_vaciado!(pedido, attrs = {})
      pedido.productos_solicitados.destroy_all
      pedido.assign_attributes({
        viendo_categorias: nil,
        busqueda: nil,
        envio_a_domicilio: false,
        direccion_envio: nil,
        horario_id: nil
      }.merge(attrs))
      pedido.save!
    end

    def cargar_productos_shell
      @cuenta_activa = @pedido.cuenta || @pedido.usuario&.cuenta
      return unless @cuenta_activa

      # rubocop:disable Naming/MemoizedInstanceVariableName
      @categorias_disponibles ||= begin
        cats_query = Productos::Categoria.where(tienda_id: current_user.tienda_activa.id)
                                         .where('categorias.menu_diario = false').order(:codigo).active
        if @pedido.turno_entrega_id.present?
          turno = @turno_cache ||= Pedidos::TurnoEntrega.find_by(id: @pedido.turno_entrega_id)
          cats_query = turno.categorias_disponibles_para_tienda(current_user.tienda_activa.id).order(:codigo) if turno && !turno.permite_todas_categorias?
        end
        current_user.tienda_activa.filtrar_categorias_para_carrito(cats_query)
      end
      # rubocop:enable Naming/MemoizedInstanceVariableName
    end

    def cargar_productos(cats = categorias_usuario)
      @cuenta_activa = @pedido.cuenta || @pedido.usuario&.cuenta
      return unless @cuenta_activa

      @categorias_disponibles ||= begin
        cats_query = Productos::Categoria.where(tienda_id: current_user.tienda_activa.id)
                                         .where('categorias.menu_diario = false').order(:codigo).active
        if @pedido.turno_entrega_id.present?
          turno = @turno_cache ||= Pedidos::TurnoEntrega.find_by(id: @pedido.turno_entrega_id)
          cats_query = turno.categorias_disponibles_para_tienda(current_user.tienda_activa.id).order(:codigo) if turno && !turno.permite_todas_categorias?
        end
        current_user.tienda_activa.filtrar_categorias_para_carrito(cats_query)
      end

      @prs = @cuenta_activa.cliente.precios_vigentes(@pedido.fecha, tienda_activa)
      @prs = @prs.where(productos: { pesable: false })
      @prs = @prs.where.not(cp: { cliente_id: nil }) if @cuenta_activa.cliente.listas_de_precio_privada?

      # Filtrar por turno de entrega si está seleccionado (reuse cached turno)
      if @pedido.turno_entrega_id.present?
        turno = @turno_cache ||= Pedidos::TurnoEntrega.find_by(id: @pedido.turno_entrega_id)
        if turno && !turno.permite_todas_categorias?
          categorias_permitidas = turno.categorias_disponibles_para_tienda(tienda_activa.id).pluck(:id)
          cats = cats.present? ? (cats.uniq & categorias_permitidas) : categorias_permitidas
        end
      end

      # Override: when tienda.muestra_mas_productos_por_categoria is enabled,
      # restrict @prs to productos whose categoria has vender_en_carrito = true.
      if tienda_activa.muestra_mas_productos_por_categoria?
        carrito_cat_ids = Productos::Categoria.where(tienda_id: tienda_activa.id)
                                              .where(vender_en_carrito: true).pluck(:id)
        cats = cats.present? ? (cats.map(&:to_i).uniq & carrito_cat_ids) : carrito_cat_ids
      end

      # Apply the category filter.
      # When muestra_mas_productos_por_categoria is true and no vender_en_carrito
      # categories exist (or the intersection is empty), cats=[] and we must
      # explicitly return zero rows — otherwise the guard `if cats.present?` is
      # false and the WHERE is skipped, showing ALL priced products (the bug).
      if cats.present?
        @prs = @prs.where(productos: { categoria_id: cats.uniq })
      elsif tienda_activa.muestra_mas_productos_por_categoria?
        @prs = @prs.none
      end
      if @pedido.busqueda.present?
        @pedido.busqueda.split.each do |term|
          sanitized = "%#{ActiveRecord::Base.sanitize_sql_like(term)}%"
          @prs = @prs.where(
            'productos.nombre LIKE :t OR productos.descripcion LIKE :t OR categorias.nombre LIKE :t',
            t: sanitized
          )
        end
      end
      fvs = current_user.favoritos.pluck(:producto_id)
      return unless fvs

      @favs = @prs.where(producto_id: fvs)
      @prs = @prs.where.not(producto_id: fvs)
    end

    def imagen_url(r)
      url_interna = r.producto.imagen_principal
      Rails.env.development? ? "http://localhost:3000#{url_interna}" : "https://#{tienda_activa.dominio}#{url_interna}"
    end

    def categorias_usuario
      if @pedido.viendo_categorias.present?
        cats = @pedido.viendo_categorias
      else
        cats = Productos::Categoria.where(tienda_id: current_user.tienda_activa).where('categorias.menu_diario = false')

        # Filtrar por turno de entrega si está seleccionado
        if @pedido.turno_entrega_id.present?
          turno = @turno_cache ||= Pedidos::TurnoEntrega.find_by(id: @pedido.turno_entrega_id)
          if turno && !turno.permite_todas_categorias?
            categorias_permitidas_ids = turno.categorias_disponibles_para_tienda(tienda_activa.id).pluck(:id)
            cats = cats.where(id: categorias_permitidas_ids)
          end
        end

        cats = cats.where(id: params[:cats]) if params[:cats].present?
        # Batch-load all togle_* preferences in one query instead of N+1
        togle_prefs = Usuarios::Preferencia.where(usuario: current_user)
                                           .where("nombre LIKE 'togle_%'")
                                           .index_by(&:nombre)
        pref_cache = cats.each_with_object({}) do |x, h|
          h[x.id] = togle_prefs["togle_#{x.nombre}"]&.estado
        end
        cats = cats.sort_by do |x|
          [(pref_cache[x.id] ? x.codigo : 0), x.codigo]
        end.map(&:id)
      end
      # @cats_restantes = cats[9..-1]
      # @cats_restantes = @cats_restantes ? @cats_restantes : nil
      # @cats_restantes = nil
      cats
    end

    def load_pedido_with_includes
      includes_chain = [:usuario, :cuenta, :local, :autor, :comprobantes,
                        { productos_solicitados: { producto: [:categoria, :stocks, :imagenes] } }]
      @pedido = Pedidos::Pedido
                .where(tienda_id: current_user.tienda_activa, id: params[:id])
                .includes(*includes_chain)
                .first

      # Cross-tienda PedidoMultiple: when a sibling pedido lives in another
      # tienda the user has access to, transparently switch tienda_activa so
      # the rest of the request renders in the pedido's tienda.
      return if @pedido || params[:id].blank?

      candidato = Pedidos::Pedido.includes(*includes_chain).find_by(id: params[:id])
      return unless candidato&.tienda && current_user.puede_loguearse_en?(candidato.tienda)

      updates = { visualizando_tienda_id: candidato.tienda_id, visualizando_local_id: nil }
      updates[:tienda_cliente_id] = candidato.tienda_id if current_user.cliente?
      current_user.update_columns(updates)

      # Force a full reload of the current_user so all in-memory caches
      # (Memoist memoizations, includes-loaded associations like
      # :visualizando_tienda / :tienda_cliente, etc.) are dropped. Without
      # this, view-level `tienda_activa` calls would return the OLD tienda
      # because login_from_session preloads :visualizando_tienda via includes
      # and `update_columns` does not refresh the loaded association object.
      # Replacing the controller's @current_authenticated_user ensures every
      # subsequent helper/view call sees the new tienda.
      reloaded = Usuarios::Usuario.where(id: current_user.id)
                                  .includes(:tienda_cliente, :visualizando_tienda,
                                            :preferencias, :favoritos, cuenta: :cliente)
                                  .first
      @current_authenticated_user = reloaded if reloaded
      @current_user = reloaded if reloaded

      @tienda_activa = nil
      @pedido = candidato

      # CRITICAL: candidato was loaded with `includes(:autor, :usuario)` BEFORE
      # we updated visualizando_tienda_id. Those preloaded user objects still
      # point at the OLD visualizando_tienda (the source tienda). If we leave
      # them stale, validations like `verificar_local` (which check
      # `autor.tienda_activa.multiple_locales?`) read the WRONG tienda's flag,
      # causing `@pedido.valid?` to return false → `_productos_en_venta`
      # partial renders empty (#productos-en-venta wrapper exists but no
      # menu-del-día / mas-productos / opciones-del-dia panels render).
      return unless reloaded

      @pedido.autor = reloaded if @pedido.autor_id == reloaded.id
      @pedido.usuario = reloaded if @pedido.usuario_id == reloaded.id
    end
  end
end
