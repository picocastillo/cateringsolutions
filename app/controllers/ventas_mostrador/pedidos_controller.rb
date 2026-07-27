module VentasMostrador
  class PedidosController < ApplicationController
    before_action :disable_turbolinks_cache
    load_resource class: Pedidos::Pedido, only: [:destroy, :edit, :update]

    def footer_aggregates
      authorize! :carga_rapida, Pedidos::Pedido
      qp = query_params.symbolize_keys.merge(no_pendientes: true)
      qp = qp.merge(local_id: current_user.local_activo.id) if current_user.local_activo
      qp[:fecha_desde] = 30.days.ago.to_date if qp[:fecha_desde].blank?
      query = Pedidos::PedidosQuery.new qp
      render json: query.footer_aggregates
    end

    def index
      @pedido = Pedidos::Pedido.where(autor_id: current_user, estado_id: 1, tienda_id: tienda_activa.id,
                                      venta_mostrador: true).last ||
                Pedidos::Pedido.new(
                  autor: current_user, estado_id: 1, venta_mostrador: true,
                  fecha: Time.zone.today, tienda_id: tienda_activa.id,
                  cuenta_id: Clientes::Cuenta.joins(cliente: :tiendas)
                             .where(nombre: 'Consumidor Final')
                             .where(tiendas: { id: tienda_activa.id })
                             .first.try(&:id)
                )
      @filtro_abierto = params[:show_filtro].present?
      authorize! :create, @pedido
      if @pedido.new_record?
        @pedido.local = current_user.local_activo || tienda_activa.locales.first
        @pedido.save!
      end
      @pedido.medios_pago.build(tipo: 'efectivo', importe: 0) if @pedido.medios_pago.empty?
      respond_to do |format|
        format.any :html, :js do
          qp = query_params.symbolize_keys.merge(no_pendientes: true)
          qp = qp.merge(local_id: current_user.local_activo.id) if current_user.local_activo
          qp[:fecha_desde] = 30.days.ago.to_date if qp[:fecha_desde].blank?
          @query = Pedidos::PedidosQuery.new qp
          @pedidos = @query.reorder(nil).order('pedidos.updated_at desc')
                           .where(venta_mostrador: true)
                           .includes(usuario: [cuenta: :cliente], cuenta: :cliente, autor: [cuenta: :cliente],
                                     productos_solicitados: { producto: :categoria })
                           .page(params[:page]).per_page(5)
        end
      end
    end

    def edit
      authorize! :edit_rapido, @pedido
      if current_user.pedidos_pendientes.present?
        current_user.pedidos_pendientes.each { |x| x.destroy! unless x == @pedido }
      end
      @pedido.update_column :estado_id, 1
      @query = Pedidos::PedidosQuery.new query_params
      @pedidos = @query.reorder(nil).order('pedidos.updated_at desc')
                       .where(venta_mostrador: true)
                       .includes(usuario: [cuenta: :cliente], cuenta: :cliente, autor: [cuenta: :cliente],
                                 productos_solicitados: { producto: :categoria })
                       .page(params[:page]).per_page(10)
      render :index
    end

    def update
      @pedido = Pedidos::Pedido.find params[:id]
      authorize! :carga_rapida, @pedido
      @pedido.assign_attributes pedido_params
      if @pedido.cuenta_id.blank?
        @pedido.cuenta = Clientes::Cuenta.joins(cliente: :tiendas)
                                         .where(nombre: 'Consumidor Final')
                                         .where(tiendas: { id: tienda_activa.id })
                                         .first
      end
      @pedido.productos_solicitados_venta_mostrador.reject(&:pesable).each(&:actualizar_precio)
      aplicar_descuento_vm(@pedido)
      error = @pedido.productos_solicitados_venta_mostrador.present? ? nil : 'Debe seleccionar productos.'
      if error.blank? && @pedido.save
        ajustar_medios_pago_post_descuento(@pedido)
        if @pedido.confirmar!
          @pedido.comprobantes.reload
          c = @pedido.comprobantes.select { |x| x.pendiente? && x.factura? }.last || @pedido.comprobantes.select do |x|
            x.confirmado? && x.factura?
          end.last
          c.confirmar! if c&.pendiente?
          begin
            c&.cobrar! current_user
          rescue StandardError => e
            Rails.logger.error "Error al cobrar pedido #{@pedido.id}: #{e.message}"
          end
          print_on_load(true, "pedido-vmi-#{@pedido.id}")
          descuento_msg = @pedido.descuento_descripcion ? " (#{@pedido.descuento_descripcion})" : ''
          redirect_to ventas_mostrador_pedidos_path,
                      notice: "Pedido #{@pedido} confirmado correctamente#{descuento_msg}. Espere la impresión del ticket."
        else
          redirect_to ventas_mostrador_pedidos_path,
                      flash: { error: "#{[@pedido.errors.full_messages.to_sentence,
                                          error].compact.compact_blank.join('.')} Error al Confirmar." }
        end
      else
        redirect_to ventas_mostrador_pedidos_path,
                    flash: { error: "#{[@pedido.errors.full_messages.to_sentence,
                                        error].compact.compact_blank.join('.')} Por favor Edite el pedido." }
      end
    end

    def destroy
      authorize! :destroy, @pedido
      nombre = @pedido.pendiente? ? '' : @pedido.to_s
      @pedido.forzar_destruccion = true
      @pedido.destroy!
      redirect_to ventas_mostrador_pedidos_path, notice: "Pedido #{nombre} eliminado correctamente."
    end

    def cambiar_cuenta
      @pedido = Pedidos::Pedido.find params[:id]
      authorize! :agregar, @pedido
      @pedido.cuenta = Clientes::Cuenta.find pedido_params[:cuenta_id].to_i if pedido_params[:cuenta_id].present?
      @pedido.fecha = pedido_params[:fecha].present? ? pedido_params[:fecha].to_date : Time.zone.today
      @pedido.productos_solicitados.clear
      @pedido.save
      @pedido.medios_pago.build(tipo: 'efectivo', importe: 0) if @pedido.medios_pago.empty?
    end

    def limpiar
      @pedido = Pedidos::Pedido.find params[:id]
      authorize! :limpiar, @pedido
      if @pedido.facturado?
        @pedido.cancelar!
      else
        @pedido.forzar_destruccion = true
        @pedido.destroy!
      end
      @pedido = Pedidos::Pedido.new(autor: current_user, estado_id: 1, venta_mostrador: true, fecha: Time.zone.today,
                                    tienda_id: tienda_activa.id,
                                    local: current_user.local_activo || tienda_activa.locales.first,
                                    cuenta_id: Clientes::Cuenta.joins(cliente: :tiendas)
                                               .where(nombre: 'Consumidor Final')
                                               .where(tiendas: { id: tienda_activa.id })
                                               .first.try(&:id))
      @pedido.save!
    end

    def cancelar
      @pedido = Pedidos::Pedido.find params[:id]
      authorize! :cancelar, @pedido
      @pedido.cancelar!
      redirect_to ventas_mostrador_pedidos_path, notice: "Pedido #{@pedido.codigo} Cancelado correctamente."
    end

    def agregar
      @pedido = Pedidos::Pedido.find params[:id]
      authorize! :agregar, @pedido
      if params[:codigo].blank? && !params[:producto_id].to_i.positive?
        @error = 'Error!<br>Ingrese un código o seleccione un producto.'
        @pedido.medios_pago.build(tipo: 'efectivo', importe: 0) if @pedido.medios_pago.empty?
        return
      end
      codigo_de_elan = nil
      if params[:producto_id].to_i.positive?
        pr = Productos::Producto.where(tienda_id: tienda_activa.id, id: params[:producto_id].to_i).first
      else
        c = params[:codigo].to_s
        if c.size == 13 && c.starts_with?('20')
          codigo_de_elan = c[1..5].to_i
          importe_elan = c[6..11].insert(4, '.').to_f
          pr = Productos::Producto.where(tienda_id: tienda_activa.id).find_by(codigo: codigo_de_elan)
        else
          pr = Productos::Producto.where(tienda_id: tienda_activa.id).find_by(codigo: c) ||
               Productos::Producto.where(tienda_id: tienda_activa.id)
                                  .where('productos.codigos_externos rlike ?',
                                         "(^|,\\s?)#{Regexp.quote(c)}($|,\\s?)")
                                  .first
        end
      end
      if pr
        # If product is pesable (sold by weight) and NOT an ELAN barcode, show peso modal
        if tienda_activa.productos_pesables? && pr.pesable? && !codigo_de_elan
          @pesable_producto = pr
          return
        end

        with_pedido_upsert_lock(@pedido.id) do
          @pedido.productos_solicitados.reload
          @ps = @pedido.productos_solicitados.find { |x| x.producto_id == pr.id }
          if @ps
            if codigo_de_elan
              @ps.cantidad = 1
              @ps.precio_unitario = @ps.precio_unitario + importe_elan
            else
              @ps.cantidad = @ps.cantidad + 1
            end
          else
            @ps = if codigo_de_elan
                    Productos::ProductoSolicitado.new(pedido: @pedido, pesable: true, cantidad: 1, producto_id: pr.id,
                                                      menu_diario_id: nil, precio_unitario: importe_elan)
                  else
                    Productos::ProductoSolicitado.new(pedido: @pedido, cantidad: 1, producto_id: pr.id,
                                                      menu_diario_id: nil)
                  end
            @ps.save
            if @ps.precio_unitario.positive?
              @pedido.productos_solicitados << @ps
            else
              @error_precio = true
            end
          end
          @pedido.save
        end
        if @pedido.errors.blank? && @error_precio.blank? && @ps.precio_unitario
          @mensaje = "Agregado:<br>#{@ps}"
        else
          @error = "Error!<br>Precio no encontrado para:<br>#{pr.codigo_y_nombre}. #{@pedido.errors.full_messages.join('<br>')}"
        end
      else
        @error = "Error!<br>Código #{params[:codigo]} no encontrado."
      end
      @pedido.medios_pago.build(tipo: 'efectivo', importe: 0) if @pedido.medios_pago.empty?
    end

    def agregar_pesable
      @pedido = Pedidos::Pedido.find params[:id]
      authorize! :agregar, @pedido

      pr = Productos::Producto.where(tienda_id: tienda_activa.id, id: params[:producto_id].to_i).first
      peso = params[:peso].to_s.gsub(',', '.').to_f

      if pr.nil?
        @error = 'Error!<br>Producto no encontrado.'
        @pedido.medios_pago.build(tipo: 'efectivo', importe: 0) if @pedido.medios_pago.empty?
        render :agregar
        return
      end

      if peso <= 0
        @error = 'Error!<br>Debe ingresar un peso válido mayor a 0.'
        @pedido.medios_pago.build(tipo: 'efectivo', importe: 0) if @pedido.medios_pago.empty?
        render :agregar
        return
      end

      @ps = @pedido.productos_solicitados.find { |x| x.producto_id == pr.id }
      if @ps
        @ps.peso = (@ps.peso || 0) + peso
      else
        @ps = Productos::ProductoSolicitado.new(pedido: @pedido, cantidad: 1, producto_id: pr.id,
                                                menu_diario_id: nil, peso: peso)
        @ps.save
        if @ps.precio_unitario&.positive?
          @pedido.productos_solicitados << @ps
        else
          @error_precio = true
        end
      end
      @pedido.save
      if @pedido.errors.blank? && @error_precio.blank? && @ps.precio_unitario
        @mensaje = "Agregado:<br>#{@ps}"
      else
        @error = "Error!<br>Precio no encontrado para:<br>#{pr.codigo_y_nombre}. #{@pedido.errors.full_messages.join('<br>')}"
      end
      @pedido.medios_pago.build(tipo: 'efectivo', importe: 0) if @pedido.medios_pago.empty?
      render :agregar
    end

    def actualizar_producto
      @pedido = Pedidos::Pedido.find params[:id]
      authorize! :agregar, @pedido
      return unless params[:productoid].to_i.positive?

      @ps = @pedido.productos_solicitados.find { |x| x.id == params[:productoid].to_i }
      return unless @ps && params[:cantidad].present?

      if params[:cantidad].to_i <= 0
        @eps = @ps.to_s
        @ps.destroy!
        @pedido.productos_solicitados.reload
      else
        @ps.cantidad = params[:cantidad].to_i
        @ps.peso = params[:peso].to_s.gsub(',', '.').to_f if params[:peso].present?
        @ps.save
      end
      @pedido.medios_pago.build(tipo: 'efectivo', importe: 0) if @pedido.medios_pago.empty?
    end

    def pedido_params
      params.require(:pedido).permit(:usuario_id, :fecha, :tipo_pedido, :cuenta_id, :para_id, :direccion_envio,
                                     :medio_pago_tipo, :local_id,
                                     medios_pago_attributes: [:id, :tipo, :importe, :_destroy],
                                     productos_solicitados_venta_mostrador_attributes: [:_destroy, :id])
    end

    def aplicar_descuento_vm(pedido)
      # Reset any previous VM discount
      pedido.descuento_venta_mostrador = nil
      pedido.monto_descuento_vm = nil

      # Determine the dominant medio de pago (highest importe)
      medio = pedido.medios_pago.reject(&:marked_for_destruction?).max_by { |m| m.importe.to_f }
      return unless medio

      # Calculate pre-discount total
      items = pedido.productos_solicitados_venta_mostrador.reject(&:marked_for_destruction?)
      return if items.empty?

      importe_total = items.sum { |ps| ps.cantidad * ps.precio_unitario.to_f }
      return unless importe_total.positive?

      importe_medio = medio.importe.to_f
      cliente = pedido.cuenta&.cliente
      descuento = VentasMostrador::DescuentoVentaMostrador.mejor_descuento_para(
        tienda: tienda_activa,
        cliente: cliente,
        medio_pago_tipo: medio.tipo,
        importe_total: importe_total,
        importe_medio: importe_medio
      )
      return unless descuento

      monto_descuento = descuento.descuento_para(importe_total, importe_medio: importe_medio)
      return unless monto_descuento.positive?

      pedido.descuento_venta_mostrador = descuento
      pedido.monto_descuento_vm = monto_descuento

      # Distribute discount proportionally across line items (same as cupon logic)
      Cupones::DistribuidorDescuento.distribuir(items, monto_descuento, importe_total)

      # Flag to skip medios_pago_cubren_total validation (medios still have pre-discount
      # amounts; we adjust them after save to avoid dual-association cache issues)
      pedido.instance_variable_set(:@skip_medios_validation, true)

      # Flush memoized importe_total
      pedido.unmemoize_all
    end

    # After save, adjust the dominant medio de pago to reflect the discounted total.
    # Done post-save via update_column to avoid dual-association cache issues that
    # cause medios_pago_cubren_total to fail during save.
    def ajustar_medios_pago_post_descuento(pedido)
      monto = pedido.monto_descuento_vm.to_f
      return unless monto.positive?

      medio = pedido.medios_pago.reload.max_by { |m| m.importe.to_f }
      return unless medio

      nuevo_importe = (medio.importe.to_f - monto).round(2)
      medio.update_column(:importe, nuevo_importe)
      medio.reload # sync in-memory state
    end
  end
end
