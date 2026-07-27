module Pedidos
  class PedidosMultiplesController < ApplicationController
    require 'mercadopago'
    before_action :load_grupo

    # GET /pedidos_multiples/:id/resumen
    def resumen
      authorize! :read, @grupo
      @pedidos = @grupo.pedidos.includes(
        :tienda, :cuenta, :turno_entrega, :horario, :cupon,
        productos_solicitados: { producto: :categoria }
      )

      # Per-pedido stock warnings (pending pedidos only)
      @productos_sin_stock = {}
      @pedidos.select(&:pendiente?).each do |pedido|
        items = []
        pedido.productos_solicitados.each do |ps|
          next unless ps.producto.categoria&.stock_activo

          disp = ps.producto.stock_actual(pedido.local&.id)
          if disp < 1
            items << { producto: ps.producto, solicitado: ps.cantidad, disponible: 0 }
          elsif ps.cantidad > disp
            items << { producto: ps.producto, solicitado: ps.cantidad, disponible: disp }
          end
        end
        @productos_sin_stock[pedido.id] = items if items.any?
      end
    end

    # POST /pedidos_multiples/:id/generar_pago_ml_multiple
    def generar_pago_ml_multiple
      authorize! :read, @grupo

      pedidos = @grupo.pedidos.includes(productos_solicitados: { producto: [:categoria, :imagenes] })

      # Per-pedido option validation. If any pedido fails, do NOT create a MP
      # preference — render JS that disables the MP button and shows inline
      # hints next to each failing pedido (mirrors single-pedido /comprar UX).
      @validation_errors_by_pedido = {}
      pedidos.select(&:pendiente?).reject { |p| p.productos_solicitados.empty? }.each do |pedido|
        errs = validation_errors_for(pedido)
        @validation_errors_by_pedido[pedido.id] = errs if errs.any?
      end

      if @validation_errors_by_pedido.any?
        respond_to { |format| format.any(:js) { render :generar_pago_ml_multiple } }
        return
      end

      its = []
      pedidos.reject { |p| p.productos_solicitados.empty? }.each do |pedido|
        pedido.productos_solicitados.each do |ps|
          title = "#{ps.nombre_carrito} (#{pedido.fecha&.strftime('%d/%m')})"
          its << {
            title: title,
            unit_price: ps.precio_efectivo.to_f,
            quantity: ps.cantidad,
            currency_id: 'ARS'
          }
        end
        next unless pedido.envio_a_domicilio && pedido.costo_envio_domicilio&.positive?

        its << { title: "Envío a domicilio #{pedido.fecha&.strftime('%d/%m')}",
                 unit_price: pedido.costo_envio_domicilio.to_f,
                 quantity: 1,
                 currency_id: 'ARS' }
      end

      payer = {
        name: current_user.to_s,
        email: current_user.email,
        identification: { type: 'DNI', number: current_user.dni }
      }

      preference_data = {
        items: its,
        payer: payer,
        back_urls: {
          success: resumen_pedido_multipl_url(@grupo, pagado: true),
          failure: resumen_pedido_multipl_url(@grupo),
          pending: resumen_pedido_multipl_url(@grupo)
        },
        payment_methods: {
          excluded_payment_types: [{ id: 'ticket' }]
        },
        statement_descriptor: 'COBRO_ML_WEB_CS',
        external_reference: "multiple-#{@grupo.id}-#{current_user.id}",
        binary_mode: true
      }

      respond_to do |format|
        format.any :js do
          mp = Mercadopago::SDK.new(Rails.application.secrets.mp)
          preference_response = mp.preference.create(preference_data)
          preference = preference_response[:response]
          @preference_id = preference['id']
          @grupo.update!(estado: Pedidos::PedidoMultiple::ESTADOS[:pagando])
        end
      end
    end

    # POST /pedidos_multiples/:id/finalizar_multiple
    # Cuenta corriente flow: accept all pending pedidos in the group.
    def finalizar_multiple
      authorize! :read, @grupo

      pedidos_pendientes = @grupo.pedidos.includes(:productos_solicitados)
                                 .select(&:pendiente?)
                                 .reject { |p| p.productos_solicitados.empty? }
      if pedidos_pendientes.empty?
        redirect_to resumen_pedido_multipl_path(@grupo), alert: 'No hay pedidos pendientes en el grupo.'
        return
      end

      errores = []
      pedidos_pendientes.each do |pedido|
        fecha_str = pedido.fecha ? I18n.l(pedido.fecha, format: :short) : 'S/F'

        per_pedido_errors = validation_errors_for(pedido)
        if per_pedido_errors.any?
          errores << "#{fecha_str}: #{per_pedido_errors.join(' ')}"
          next
        end

        pedido.aceptar(current_user)
        errores << "#{fecha_str}: #{pedido.errors.full_messages.to_sentence}" unless pedido.save
      end

      if errores.any?
        redirect_to resumen_pedido_multipl_path(@grupo), alert: errores.join(' | ')
      else
        redirect_to pedidos_path, notice: "#{pedidos_pendientes.size} pedido#{'s' if pedidos_pendientes.size > 1} finalizados correctamente."
      end
    end

    private

    # Mirror of PedidosController#generar_pago_ml validation block, applied per
    # pedido. Returns array of error strings (empty array = valid). Each pedido
    # is validated against ITS OWN tienda's settings (not tienda_activa) so the
    # group can legitimately span multiple tiendas.
    def validation_errors_for(pedido)
      errors = []
      cliente = pedido.cuenta&.cliente
      return ['El pedido no tiene cuenta asignada.'] unless cliente

      tienda = pedido.tienda
      return ['El pedido no tiene tienda asignada.'] unless tienda

      if tienda.carrito_de_compras? && cliente.turnos_activos.any?
        if pedido.turno_entrega_id.blank?
          errors << "Seleccioná un 'Turno de Entrega' para continuar."
        elsif !cliente.tiene_turno?(pedido.turno_entrega_id)
          errors << 'El turno de entrega seleccionado no está disponible para tu cuenta.'
        end
      end

      if !tienda.carrito_de_compras? && cliente.horarios_de_entrega? &&
         tienda.horarios_de_entrega? && pedido.horario_id.blank?
        errors << "Seleccioná un 'Horario' de envío para continuar."
      end

      if !pedido.pedido_para_empresa && cliente.usuario_puede_elegir_cuenta && pedido.enviar_a_id.blank?
        errors << 'Completá el campo Enviar A para definir el destino del envío.'
      end

      errors << 'Ingresá la dirección de envío a domicilio.' if pedido.envio_a_domicilio && pedido.direccion_envio.blank?

      errors
    end

    def load_grupo
      @grupo = Pedidos::PedidoMultiple
               .includes(pedidos: [:tienda, :cuenta, :usuario, { productos_solicitados: :producto }])
               .find(params[:id])
    end
  end
end
