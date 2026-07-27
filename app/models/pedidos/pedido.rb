module Pedidos
  class Pedido < ApplicationRecord
    require 'ulid'
    include Pedidos::Broadcastable

    acts_as_discontinued
    extend Memoist

    has_many :productos_solicitados, class_name: 'Productos::ProductoSolicitado', dependent: :destroy, autosave: true, before_add: ->(t, i) { i.pedido = t }
    accepts_nested_attributes_for :productos_solicitados, allow_destroy: true, reject_if: lambda { |attrs|
      attrs['cantidad'].to_f <= 0 || attrs['producto_id'].blank?
    }

    has_many :productos_solicitados_venta_mostrador,
             -> { order('productos_solicitados.id desc') },
             class_name: 'Productos::ProductoSolicitado', foreign_key: :pedido_id,
             dependent: :destroy, autosave: true, before_add: ->(t, i) { i.pedido = t }
    accepts_nested_attributes_for :productos_solicitados_venta_mostrador,
                                  allow_destroy: true, reject_if: lambda { |attrs|
                                    attrs['cantidad'].to_f <= 0 || attrs['producto_id'].blank?
                                  }

    belongs_to :tienda, class_name: 'Tiendas::Tienda'

    belongs_to :local, class_name: 'Locales::Local', optional: true

    belongs_to :autor, class_name: 'Usuarios::Usuario'
    belongs_to :usuario, class_name: 'Usuarios::Usuario', optional: true
    belongs_to :cuenta, class_name: 'Clientes::Cuenta', optional: true
    has_many :comprobantes, class_name: 'Comprobantes::Comprobante', dependent: :destroy
    belongs_to :horario, class_name: 'Pedidos::Horario', optional: true
    belongs_to :turno_entrega, class_name: 'Pedidos::TurnoEntrega', optional: true
    belongs_to :cupon, class_name: 'Cupones::Cupon', optional: true
    belongs_to :descuento_venta_mostrador, class_name: 'VentasMostrador::DescuentoVentaMostrador', optional: true
    belongs_to :pedido_multiple, class_name: 'Pedidos::PedidoMultiple', optional: true

    has_many :pagos_electronicos, class_name: 'Ventas::Facturacion::PagoElectronico',
                                  dependent: :destroy

    has_many :medios_pago, class_name: 'Pedidos::MedioPago', dependent: :destroy
    accepts_nested_attributes_for :medios_pago, allow_destroy: true,
                                                reject_if: ->(attrs) { attrs['importe'].to_f.zero? && attrs['tipo'].blank? }

    enum :estado, class_name: 'Pedidos::Estado'

    before_validation :asignar_cuenta
    before_validation :asignar_tienda
    before_validation :descartar_medios_pago_vacios, if: :venta_mostrador?
    before_save :rectificar_pedido
    before_save :asignar_horario
    before_save :asignar_codigo
    before_save :limpiar_turno_entrega_invalido
    before_destroy :prevenir_destruccion_si_pago_o_facturado, prepend: true
    after_save :crear_comprobante, :updatear_avisos_cocina

    attr_accessor :mark_for_desctruccion, :no_validar_fecha, :forzar_destruccion

    has_many :documentos, -> { order :position }, as: :documentable, dependent: :destroy, class_name: 'Infraestructura::Documento'
    has_many :imagenes, lambda {
      order(:position).where('documento_content_type like "%image%"')
    }, as: :documentable, dependent: :destroy, class_name: 'Infraestructura::Documento'

    validates :fecha, presence: { unless: :pendiente? }
    validates :usuario, presence: { if: :cuando_validar_usuario? }
    validates :cuenta, presence: { unless: :pendiente? }
    validate :fecha_valida
    validate :direccion_cargada
    validate :verificar_horario
    validate :verificar_local
    validate :medios_pago_cubren_total, if: :venta_mostrador?
    validate :pedido_multiple_owner_matches
    validates :productos_solicitados, presence: { unless: :pendiente? }
    scope :fecha_desde, ->(f) { where(pedidos: { fecha: f.to_date.. }) }
    scope :fecha_hasta, ->(f) { where(pedidos: { fecha: ..f.to_date }) }

    def to_s
      estado_id == 1 ? 'Pedido' : (codigo || "Pedido ##{id}")
    end

    def codigo_s
      "Pedido #{codigo}"
    end

    def test
      broadcast_daily_orders_update
    end

    def tipo_pedido=(tp)
      self.pedido_para_empresa = tp.to_i == 2
    end

    def tipo_pedido
      pedido_para_empresa ? 2 : 1
    end

    def confirmar_y_crear_pago(user, payment_id, merchant_order_id)
      return unless payment_id.present? && merchant_order_id.present?

      confirmar! user unless facturado?
      @facturando = false
      existente = pagos_electronicos.select do |x|
        x.pago_id == payment_id.to_i && x.order_id == merchant_order_id.to_i
      end.first
      existente ||= Ventas::Facturacion::PagoElectronico.new
      existente.pago_id = payment_id
      existente.order_id = merchant_order_id
      (pagos_electronicos << existente) if existente.new_record?
    end

    def desimputar_pago(response)
      self.no_validar_fecha = true
      # external_reference formats:
      #   single pedido:      "{pedido_id}-{user_id}"   (count == 2)
      #   multi pedido group: "multiple-{grupo_id}-{user_id}" (count == 3)
      ref_parts = response['external_reference'].to_s.split('-')
      uid = ref_parts.count == 3 && ref_parts[0] == 'multiple' ? ref_parts[2] : ref_parts[1]
      user = uid.present? ? Usuarios::Usuario.find_by(id: uid) : nil
      return unless user && (user == autor || ((user.operador? || user.admin?) && user.tiendas.include?(tienda)))

      existente = pagos_electronicos.select do |x|
        x.pago_id == response['id'].to_i && x.order_id = response['order']['id'].to_i
      end.first
      existente ||= Ventas::Facturacion::PagoElectronico.new
      existente.pago_id = response['id'].to_i
      existente.order_id = response['order']['id'].to_i
      existente.date_created = response['date_created']
      existente.date_approved = response['date_approved']
      existente.date_last_updated = response['date_last_updated']
      existente.money_release_date = response['money_release_date']
      existente.payment_method_id = response['payment_method_id']
      existente.payment_type_id = response['payment_type_id']
      existente.status = response['status']
      existente.status_detail = response['status_detail']
      existente.currency_id = response['currency_id']
      existente.description = response['description']
      existente.collector_id = response['collector_id']
      existente.installments = response['installments']
      existente.transaction_amount = response['transaction_amount']
      existente.transaction_amount_refunded = response['transaction_amount_refunded']
      existente.coupon_amount = response['coupon_amount']
      existente.total_paid_amount = response['transaction_details']['total_paid_amount']
      existente.overpaid_amount = response['transaction_details']['overpaid_amount']
      existente.net_received_amount = response['transaction_details']['net_received_amount']
      existente.installment_amount = response['transaction_details']['installment_amount']
      (pagos_electronicos << existente) if existente.new_record?
      if cobrado
        pds = comprobantes.select(&:confirmado?)
        pds.each do |c|
          c.afectadores.select { |x| x.is_a?(Cobros::Recibo) && (x.finalizado? || x.confirmado?) }.each(&:destroy!)
        end
        false
      end
      update_column :facturado, false
      update_column :cobrado, false
      @facturando = false
      save!
    end

    def imputar_pago(response)
      self.no_validar_fecha = true
      # external_reference formats:
      #   single pedido:      "{pedido_id}-{user_id}"   (count == 2)
      #   multi pedido group: "multiple-{grupo_id}-{user_id}" (count == 3)
      ref_parts = response['external_reference'].to_s.split('-')
      uid = ref_parts.count == 3 && ref_parts[0] == 'multiple' ? ref_parts[2] : ref_parts[1]
      user = uid.present? ? Usuarios::Usuario.find_by(id: uid) : nil
      authorized = user && (user == autor || ((user.operador? || user.admin?) && user.tiendas.include?(tienda)))
      unless authorized
        # For multi-pedido payments the job already validated the group and pedido
        # ownership against the MP webhook. Fall back to autor so payments are never
        # silently dropped when the paying user can't be found (e.g. account deleted
        # after the preference was created, or group with pedidos from multiple users).
        return unless ref_parts[0] == 'multiple'

        user = autor
        return unless user
      end

      # Ensure a local is set before any save runs verificar_local. A pedido
      # reaching payment confirmation without a local is possible for old records
      # created before multiple_locales was enabled, or when the checkout step
      # didn't enforce it. Priority: tienda's carrito default, then user's active local.
      # Applied unconditionally because the final `save!` below also runs verificar_local
      # for pedidos that arrive here already confirmado/facturado (duplicate webhooks).
      self.local ||= tienda.local_para_carrito || autor&.local_activo if tienda&.multiple_locales? && local.nil?
      if !confirmado? && !facturado?
        confirmar!(user)
        reload
      end
      @facturando = false
      existente = pagos_electronicos.select do |x|
        x.pago_id == response['id'].to_i && x.order_id = response['order']['id'].to_i
      end.first
      existente ||= Ventas::Facturacion::PagoElectronico.new
      existente.pago_id = response['id'].to_i
      existente.order_id = response['order']['id'].to_i
      existente.date_created = response['date_created']
      existente.date_approved = response['date_approved']
      existente.date_last_updated = response['date_last_updated']
      existente.money_release_date = response['money_release_date']
      existente.payment_method_id = response['payment_method_id']
      existente.payment_type_id = response['payment_type_id']
      existente.status = response['status']
      existente.status_detail = response['status_detail']
      existente.currency_id = response['currency_id']
      existente.description = response['description']
      existente.collector_id = response['collector_id']
      existente.installments = response['installments']
      existente.transaction_amount = response['transaction_amount']
      existente.transaction_amount_refunded = response['transaction_amount_refunded']
      existente.coupon_amount = response['coupon_amount']
      existente.total_paid_amount = response['transaction_details']['total_paid_amount']
      existente.overpaid_amount = response['transaction_details']['overpaid_amount']
      existente.net_received_amount = response['transaction_details']['net_received_amount']
      existente.installment_amount = response['transaction_details']['installment_amount']
      if existente.new_record?
        (pagos_electronicos << existente)
      else
        existente.save!
      end

      existente.reload

      unless cobrado
        cobrados = []
        pds = comprobantes.select(&:confirmado?)
        pds.each do |c|
          next if c.saldo <= 0

          c.medio_de_pago = existente
          c.cobrar!
          cobrados << c.valid?
        end
        update_column :cobrado, true
      end
      save!
    end

    def enviar_a_id=(i)
      if i.to_i == -1
        self.envio_a_domicilio = true
        tienda_cliente = cuenta&.cliente&.tienda
        costo = tienda_cliente&.costo_envio_domicilio
        self.costo_envio_domicilio = costo&.positive? ? costo.to_f : 0
      else
        c = cuenta || usuario.cuenta
        if c.cliente.usuario_puede_elegir_cuenta
          cu = c.cliente.cuentas.select { |x| x.id == i.to_i }.first
          asignar_cuenta_manual if cu
        end
        self.cuenta = cu if cu
        self.direccion_envio = nil
        self.envio_a_domicilio = false
        self.costo_envio_domicilio = 0
      end
    end

    def enviar_a_id
      envio_a_domicilio ? -1 : cuenta.try(&:id)
    end

    def asignar_cuenta
      return unless (aceptado? || pendiente?) && !@asigno_cuenta_manual && usuario && usuario.cuenta != cuenta

      # Self-heal: a pedido's cuenta must always belong to the same cliente as the
      # usuario. If a different cliente's cuenta sneaks in (stale form value, a
      # cross-cliente usuario/cuenta pair persisted by an earlier request, etc.)
      # the usuario wins — fall through and override cuenta with usuario.cuenta
      # below instead of raising. This keeps any poisoned pendiente self-healing
      # on the next valid?/save instead of 500-ing the cart.

      # When the cliente lets the user pick a destination cuenta (Enviar a), any
      # cuenta that belongs to the same cliente as the user's default cuenta is a
      # valid deliberate choice — don't silently revert it back to usuario.cuenta
      # on follow-up saves (the in-memory @asigno_cuenta_manual flag does not
      # survive across requests, but the persisted cuenta_id does).
      return if cuenta && usuario.cuenta &&
                cuenta.cliente_id == usuario.cuenta.cliente_id &&
                usuario.cuenta.cliente&.usuario_puede_elegir_cuenta

      self.cuenta = usuario.cuenta
    end

    def asignar_cuenta_manual
      @asigno_cuenta_manual = true
    end

    def enviar_a_string
      s = if envio_a_domicilio
            "#{direccion_envio.capitalize} <i>(Domicilio Particular)</i>"
          else
            cuenta ? cuenta.cliente_y_nombre : 'Empresa'
          end
      s.html_safe
    end

    def opciones_de_envio
      ops = []
      c = cuenta || usuario.cuenta
      if c.cliente.usuario_puede_elegir_cuenta
        c.cliente.cuentas.each { |x| ops << [x.cliente_y_nombre, x.id] }
      else
        ops << [c.cliente_y_nombre, c.id]
      end
      ops << ['Domicilio Particular', -1] if c.cliente.permitir_envios_a_domicilio
      ops
    end

    def self.borrar_pendientes
      Pedidos::Pedido.where(estado_id: 1).where(created_at: ...12.hours.ago).destroy_all
    end

    def para_id=(id)
      self.para = id
    end

    def para_id
      para
    end

    def para_to_s_vertical
      a = nil
      if usuario
        a = to_s_vertical
      elsif cuenta
        c = if cuenta.nombre == cuenta.cliente.nombre
              ''
            else
              "<div class='nowrap' style='margin-top:-3px'>#{cuenta.cliente}</div>"
            end
        style_div = c.present? && para.present? ? 'font-size:13px;margin-top:-3px' : 'font-size: 1rem;'
        s = "<span class='muted'>#{para}</span>
          <div class='nowrap' style='#{style_div}'>
            #{cuenta.nombre}
            #{c}
          </div>"
        a = s.html_safe
      else
        a = nombre
      end
      a
    end

    def to_s_vertical
      return unless usuario

      if usuario.cuenta
        cu = cuenta || usuario.cuenta
        c = cu.nombre == cu.cliente.nombre ? '' : "<div class='nowrap' style='margin-top:-3px'>#{cu.cliente}</div>"
        cu = cuenta.cliente.usuario_puede_elegir_cuenta ? '' : cu.nombre
        s = "#{usuario.nombre_normalizado}
        <div class='muted nowrap' style='margin-top:4px;margin-left:15px'>
          #{cu}
          #{c}
        </div>"
        s.html_safe
      else
        usuario.nombre_normalizado
      end
    end

    def cargando
      @cargando = true
      self
    end

    def cargando_inicial?
      @cargando
    end

    def codigo_completo
      codigo_formateado.to_s
    end

    def setear_direccion_y_asignar_costo_envio
      return unless pendiente? && usuario&.cliente&.permitir_envios_a_domicilio

      self.direccion_envio = usuario.direccion_envio if direccion_envio.blank? && usuario.direccion_envio.present?
    end

    def viendo_categorias=(csv)
      self.viendo_categorias_csv = csv&.join(',')
    end

    def viendo_categorias
      viendo_categorias_csv&.split(',')&.map(&:to_i)
    end

    def codigo_formateado
      format('%08d', codigo.to_i)
    end

    def hora_actual
      t = Time.current
      Time.zone.local(2000, 1, 1, t.hour, t.min)
    end

    def self.now
      t = Time.current
      Time.zone.local(2000, 1, 1, t.hour, t.min)
    end

    def to_s_growl
      "#{fecha}: #{'(Cancelado) ' if discontinued?}#{usuario}"
    end

    def to_s_horario
      "#{usuario} (#{fecha})"
    end

    def usuarios_alcanzados
      [usuario]
    end

    def productos_carga_simple_id; end

    def productos_carga_simple_id=(ids); end

    def updatear_avisos_cocina
      return if tienda.nil? || !tienda.carrito_de_compras || pendiente?
      return unless saved_change_to_estado_id?

      broadcast_daily_orders_update
    end

    def crear_comprobante
      return if estado_id == 1 || !@facturando

      if estado_id == 3 && comprobantes.any?(&:pendiente?)
        comprobantes.select(&:pendiente?).each(&:confirmar!)
      elsif estado_id == 5
        comprobante_existente = comprobantes.where(estado_id: 2,
                                                   type: 'Ventas::Facturacion::Factura').order(created_at: :desc).first
        anular_factura autor, comprobante_existente if comprobante_existente
      else
        factura = comprobantes.where(estado_id: 1,
                                     type: 'Ventas::Facturacion::Factura').order(created_at: :desc).first
        if factura
          if costo_envio_domicilio.positive? && envio_a_domicilio
            envio = [Ventas::Facturacion::Renglon.new(cantidad: 1, descripcion: 'Envío a domicilio',
                                                      precio_unitario: costo_envio_domicilio)]
          end
          new_renglones = productos_solicitados.map { |x| Ventas::Facturacion::Renglon.new(producto: x.producto, cantidad: x.cantidad, descripcion: x.producto.to_s, precio_unitario: x.precio_unitario, peso: x.peso) }
          new_renglones += envio if envio
          factura.renglones = new_renglones
          factura.completar_on_save = true
          factura.save!
        else
          comprobante_existente = comprobantes
                                  .where(estado_id: 2, type: 'Ventas::Facturacion::Factura')
                                  .order(created_at: :desc).first
          anular_factura autor, comprobante_existente if comprobante_existente
          f = crear_factura autor
          f.save!
        end
      end
    end

    def anular_factura(u, comprobante)
      return unless comprobante

      # Pessimistic lock on the factura serialises concurrent anular_factura
      # flows (cron + MercadoPago webhook + manual retry) so the cumulative
      # NC check below sees a consistent view and we never create two NCs
      # that together over-credit the factura.
      comprobante.with_lock do
        comprobante.afectadores.reload
        total_factura = comprobante.total.to_f
        ya_creditado = comprobante.afectadores
                                  .select { |x| x.is_a?(Ventas::Facturacion::NotaCredito) && x.confirmado? }
                                  .sum { |nc| nc.total.to_f.abs }
        next if total_factura.positive? && ya_creditado >= total_factura - 0.01

        comprobante.afectadores.each { |x| x.anular!(u) }
        nc = Ventas::Facturacion::NotaCredito.generar_nc_pedido(comprobante)
        if nc
          # When partial credits already exist against this factura (e.g. a discount NC
          # from descuento_venta_mostrador or cupon on the previous confirmation), a
          # full-amount cancelation NC would exceed the factura total and fail
          # no_excede_total_factura on nc.confirmar(u).save! (where nc.total is already
          # computed by before_save :completar). Scale the NC renglones down so the new
          # NC only covers the remaining uncredited amount (total_factura - ya_creditado).
          if ya_creditado > 0.01 && nc.renglones.any?
            neto = total_factura - ya_creditado
            nc_gross = nc.renglones.sum { |r| r.precio_unitario.to_f * r.cantidad.to_f }
            if nc_gross > 0.01
              factor = neto / nc_gross
              nc.renglones.each { |r| r.precio_unitario = (r.precio_unitario.to_f * factor).round(2) }
            end
          end
          nc.completar_on_save = true
          nc.local ||= local || comprobante.local || u&.local_activo
          nc.save!
          nc.confirmar(u).save!
        else
          error_al_generar_nc_para_pedido
        end
      end
    end

    def ultimo_remito
      comprobantes.select { |x| x.confirmado? && x.is_a?(Ventas::Facturacion::Factura) }.last
    end

    def crear_factura(u)
      if costo_envio_domicilio.positive? && envio_a_domicilio
        envio = [{ cantidad: 1, descripcion: 'Envío a domicilio',
                   precio_unitario: costo_envio_domicilio }]
      end
      new_renglones = productos_solicitados.map do |x|
        { producto: x.producto, cantidad: x.cantidad, descripcion: x.producto.to_s,
          precio_unitario: x.precio_unitario, peso: x.peso }
      end
      new_renglones += envio if envio
      fecha_emision = Time.current.change(day: fecha.day, month: fecha.month, year: fecha.year)
      factura = Ventas::Facturacion::Factura.create!(
        tienda: tienda, pedido: self, fecha_emision: fecha_emision,
        completar_on_save: true, cuenta: cuenta, autor: u, renglones: new_renglones,
        local: local
      )

      crear_nc_descuento(factura) if tiene_descuento_cupon? || tiene_descuento_vm?

      factura
    end

    def aceptar(usuario = nil)
      self.estado_id = 2
      self.busqueda = nil
      self.viendo_categorias_csv = nil
      self.aceptado_el = Time.current
      self.aceptado_por_id = usuario&.id
      @facturando = true
    end

    def aceptar!(usuario = nil)
      # Bug C: pessimistic lock + state re-check mirror confirmar! so a racing
      # double-submit (or retry, or webhook + cron overlap) cannot run the
      # crear_comprobante callback twice and produce a duplicate factura.
      with_lock do
        next if estado_id && estado_id >= 2

        aceptar(usuario)
        save!
      end
      true
    end

    def facturando
      @facturando = true
    end

    def confirmar!(user = nil)
      # Use pessimistic lock to prevent race between cron job, webhook, and admin actions
      already_confirmed = false

      with_lock do
        # Re-check state inside lock — another process may have already confirmed
        if confirmado? || estado_id == 3
          already_confirmed = true
          next
        end

        self.estado_id = 3
        self.busqueda = nil
        self.viendo_categorias_csv = nil
        self.no_validar_fecha = true
        @facturando = true
        self.facturado = true

        # Reducir stock si no fue reducido en aceptar
        reducir_stock_si_necesario

        save!
      end

      return facturado if already_confirmed

      comprobantes.reload
      facturados = []
      pds = comprobantes.select(&:pendiente?)
      pds.each do |c|
        c.confirmar! user
        facturados << c.valid?
      end
      update_column :facturado, false if facturados.blank? || facturados.any? { |f| f != true }
      facturado
    end

    def reducir_stock_si_necesario
      return if stock_reducido
      return unless tienda&.maneja_stock?

      local_id = local&.id

      # Preload associations to avoid N+1 queries (only for AR relations)
      ps_list = productos_solicitados
      ps_list = ps_list.includes(producto: [:categoria, :stocks]) if ps_list.respond_to?(:includes)

      errores_stock = []

      ps_list.each do |ps|
        next unless ps.producto
        next unless ps.producto.categoria&.stock_activo?

        stock = ps.producto.stock_for_local(local_id)
        next unless stock

        # Reduce stock — track failures
        cantidad_a_reducir = ps.peso.present? ? ps.cantidad * ps.peso : ps.cantidad
        unless stock.reducir_stock(cantidad_a_reducir, 'venta')
          errores_stock << "#{ps.producto.nombre}: stock insuficiente " \
                           "(disponible: #{stock.reload.cantidad_actual}, solicitado: #{ps.cantidad})"
        end
      end

      # Mark stock as reduced in database to prevent duplicate reduction
      update_column(:stock_reducido, true)

      # Log failures but don't block the order — stock was already validated before accepting
      return unless errores_stock.any?

      Rails.logger.warn "STOCK WARNING pedido ##{id}: #{errores_stock.join(', ')}"
    end

    def cancelar!
      # Wrap in transaction so stock restoration and estado change are atomic
      self.class.transaction do
        with_lock do
          # Re-check state inside lock — another process may have already cancelled
          next if cancelado?

          self.no_validar_fecha = true
          self.estado_id = 5
          self.busqueda = nil
          self.viendo_categorias_csv = nil
          self.no_validar_fecha = true
          @facturando = true

          # Restore stock if it was previously reduced
          restaurar_stock_si_fue_reducido

          save!
        end
      end
    end

    def restaurar_stock_si_fue_reducido
      return unless stock_reducido
      return unless tienda&.maneja_stock?

      local_id = local&.id

      # Preload associations to avoid N+1 queries (only for AR relations)
      ps_list = productos_solicitados
      ps_list = ps_list.includes(producto: [:categoria, :stocks]) if ps_list.respond_to?(:includes)

      ps_list.each do |ps|
        next unless ps.producto
        next unless ps.producto.categoria&.stock_activo?

        stock = ps.producto.stock_for_local(local_id)
        next unless stock

        # Return stock using devolucion movement
        stock.aumentar_stock(ps.cantidad, 'devolucion - pedido cancelado', nil)
      end

      # Mark stock as no longer reduced
      update_column(:stock_reducido, false)
    end

    def cancelado?
      estado_id == 5
    end

    def pendiente?
      estado_id == 1
    end

    def en_grupo?
      pedido_multiple_id.present?
    end

    def hermanos
      return Pedidos::Pedido.none unless en_grupo?

      pedido_multiple.pedidos.where.not(id: id)
    end

    def importe_total
      return if productos_solicitados.blank?

      if tiene_descuento_cupon? || tiene_descuento_vm?
        importe_total_sin_descuento - importe_descuento_total
      else
        Danconia::Money.new(productos_solicitados.map do |x|
          x.importe_total.to_f
        end.sum)
      end
    end
    memoize :importe_total

    def importe_total_sin_descuento
      return if productos_solicitados.blank?

      Danconia::Money.new(productos_solicitados.map do |x|
        x.importe_total_sin_descuento.to_f
      end.sum)
    end

    def tiene_descuento_cupon?
      cupon.present? && productos_solicitados.any?(&:tiene_descuento?)
    end

    def tiene_descuento_vm?
      descuento_venta_mostrador.present? && productos_solicitados.any?(&:tiene_descuento?)
    end

    def importe_descuento_cupon
      return Danconia::Money.new(0) unless tiene_descuento_cupon?

      Danconia::Money.new(cupon.descuento_para(importe_total_sin_descuento.to_f))
    end

    def importe_descuento_vm
      return Danconia::Money.new(0) unless tiene_descuento_vm?

      Danconia::Money.new(monto_descuento_vm || 0)
    end

    def importe_descuento_total
      if tiene_descuento_cupon?
        importe_descuento_cupon
      elsif tiene_descuento_vm?
        importe_descuento_vm
      else
        Danconia::Money.new(0)
      end
    end

    def descuento_descripcion
      if tiene_descuento_cupon?
        "Cupón #{cupon.codigo}: #{cupon.descuento_descripcion}"
      elsif tiene_descuento_vm?
        descuento_venta_mostrador.nombre
      end
    end

    def crear_nc_descuento(factura)
      discounted_items = productos_solicitados.select(&:tiene_descuento?)
      return if discounted_items.empty?

      fuente_descuento = cupon || descuento_venta_mostrador
      return unless fuente_descuento

      discount_total = if descuento_venta_mostrador.present?
                         monto_descuento_vm.to_f
                       else
                         fuente_descuento.descuento_para(importe_total_sin_descuento.to_f)
                       end
      return if discount_total.zero?

      desc_label = if cupon.present?
                     "Descuento cupón #{cupon.codigo}"
                   else
                     "Descuento #{descuento_venta_mostrador.nombre}"
                   end

      total_discounted = discounted_items.sum { |x| x.precio_unitario * x.cantidad }
      sum_applied = 0.0

      renglones_nc = discounted_items.each_with_index.map do |x, index|
        if index == discounted_items.length - 1
          item_discount = (discount_total - sum_applied).round(2)
        else
          proporcion = (x.precio_unitario * x.cantidad) / total_discounted
          item_discount = (discount_total * proporcion).round(2)
          sum_applied += item_discount
        end

        Ventas::Facturacion::Renglon.new(
          producto: x.producto, cantidad: 1,
          descripcion: "#{desc_label} - #{x.producto} (#{x.cantidad.to_i} un.)",
          precio_unitario: item_discount
        )
      end

      nc = Ventas::Facturacion::NotaCredito.new
      nc.preparar_para_cancelar_a(factura, renglones_nc, factura)
      nc.completar_on_save = true
      nc.save!
    end

    def aplicar_cupon!(cupon)
      raise 'Solo cupones vigentes pueden ser usados' unless cupon.vigente?

      total = productos_solicitados.map { |ps| ps.precio_unitario * ps.cantidad }.sum
      descuento_total = cupon.descuento_para(total)
      return if descuento_total.zero?

      Cupones::DistribuidorDescuento.distribuir(productos_solicitados, descuento_total, total)

      self.cupon = cupon
      save!
      flush_cache(:importe_total)
    end

    def quitar_cupon!
      productos_solicitados.each { |ps| ps.precio_con_descuento = nil }
      self.cupon = nil
      save!
      flush_cache(:importe_total)
    end

    # Re-applies the current cupon discount across all productos_solicitados.
    # Call after adding/removing products or changing quantities.
    # Returns :ok, :expired, or :none
    def reaplicar_cupon!
      return :none if cupon.blank?

      # Check cupon still valid (can't use vigente? because usado? is true for this pedido)
      if cupon.cancelado? || (cupon.fecha_vencimiento.present? && cupon.fecha_vencimiento < Date.current)
        quitar_cupon!
        return :expired
      end

      active_ps = productos_solicitados.reject(&:marked_for_destruction?)
      total = active_ps.sum { |ps| ps.precio_unitario * ps.cantidad }

      if total.zero?
        quitar_cupon!
        return :expired
      end

      descuento_total = cupon.descuento_para(total)

      Cupones::DistribuidorDescuento.distribuir(active_ps, descuento_total, total)

      # Batch-update precio_con_descuento directly, skipping callbacks (asignar_precio etc.)
      # since we only need to persist the recalculated discount prices.
      active_ps.each { |ps| ps.update_columns(precio_con_descuento: ps.precio_con_descuento) }
      flush_cache(:importe_total)
      :ok
    end

    def limite_compra_excedido?
      !!mensaje_limite_compra_excedido
    end

    def mensaje_limite_compra_excedido
      return unless importe_total

      cliente = cuenta&.cliente
      return unless cliente

      # Sum pedidos for the same usuario + same fecha (daily limit per user)
      otros_pedidos_del_dia = Pedidos::Pedido
                              .joins(:cuenta)
                              .where(cuentas: { cliente_id: cliente.id })
                              .where(fecha: fecha)
                              .where(usuario_id: usuario_id)
                              .where.not(estado_id: 5)
                              .where.not(id: id)
                              .joins(:productos_solicitados)
                              .sum('productos_solicitados.cantidad * COALESCE(productos_solicitados.precio_con_descuento, productos_solicitados.precio_unitario) * COALESCE(productos_solicitados.peso, 1)')
                              .to_f

      total_dia = importe_total.to_f + otros_pedidos_del_dia

      limite_pesos = cliente.limite_compra_pesos if cliente.limite_compra_pesos.present?
      limite_dolares_en_pesos = nil
      if cliente.limite_compra_dolares.present?
        precio_dolar = Cotizaciones::Dolar.precio_para_fecha(fecha)
        limite_dolares_en_pesos = cliente.limite_compra_dolares * precio_dolar if precio_dolar&.positive?
      end

      # When both limits are set, use the lowest converted to pesos
      limite_efectivo = [limite_pesos, limite_dolares_en_pesos].compact.min

      return unless limite_efectivo && total_dia > limite_efectivo

      if limite_efectivo == limite_dolares_en_pesos && limite_dolares_en_pesos != limite_pesos
        "El total del día ($#{'%.2f' % total_dia}) supera el límite diario de compra " \
          "de US$#{'%.2f' % cliente.limite_compra_dolares} ($#{'%.2f' % limite_dolares_en_pesos})."
      else
        "El total del día ($#{'%.2f' % total_dia}) supera el límite diario " \
          "de compra de $#{'%.2f' % limite_pesos}."
      end
    end

    def confirmado?
      estado_id == 3
    end

    def aceptado?
      estado_id == 2
    end

    def refacturar_completo
      productos_solicitados.each do |r|
        r.actualizar_precio
        r.save!
      end
      if confirmado?
        confirmar!
      elsif comprobantes.last
        comprobantes.last&.renglones&.each do |r|
          r.actualizar_precio
          r.save!
        end
      end
    end

    def fecha_permitida?
      fv = true
      c = cuenta
      fv = c.fecha_permitida?(fecha, autor) if c && fecha
      fv
    end

    def verificar_tienda(tienda_param)
      return false unless tienda == tienda_param

      (tienda.carrito_de_compras && !venta_mostrador) || (tienda.venta_mostrador && venta_mostrador)
    end

    # Safety net so a pedido is never silently destroyed once it carries
    # collected money or has already moved past the cart stage. We deliberately
    # do NOT block facturado-only pedidos: the legitimate `cancelar` /
    # `anular_factura` flow destroys pedidos that have a pending factura and
    # generates a nota de crédito for any confirmed comprobante. The dangerous
    # state is `cobrado` (money received), `pagos_electronicos` (MP payment
    # already linked), or estado >= 3 (confirmado/finalizado — stock reduced
    # and kitchen already notified). Callers that legitimately need to delete
    # such a pedido (chargeback reconciliation) must set
    # `pedido.forzar_destruccion = true` first.
    def prevenir_destruccion_si_pago_o_facturado
      return if forzar_destruccion
      return unless cobrado? || pagos_electronicos.exists?

      errors.add(:base, 'No se puede eliminar un pedido cobrado o con pago electrónico registrado.')
      throw :abort
    end

    # SECURITY (incident 2026-05-17 PM 78): block cross-user contamination at
    # the model level. If this pedido is linked to a usuario-owned group, the
    # group's usuario_id must match either our autor_id (admin authoring on
    # behalf of an employee in the same cuenta) or our usuario_id. Cuenta-only
    # groups (admin-empresa shared bucket) require matching cuenta_id.
    def pedido_multiple_owner_matches
      return if pedido_multiple_id.nil?

      grupo = pedido_multiple
      return if grupo.nil?

      if grupo.usuario_id.present?
        return if [autor_id, usuario_id].compact.include?(grupo.usuario_id)
      elsif grupo.cuenta_id.present? && cuenta_id == grupo.cuenta_id
        return
      end

      errors.add(:pedido_multiple_id, 'no pertenece a este usuario')
    end

    private

    def asignar_codigo
      return if estado_id == 1 || codigo

      self.created_at = Time.current
      self.fecha = Time.zone.today if venta_mostrador
      self.codigo = Infraestructura::GeneradorSecuencial.proximo("tienda#{tienda_id}_pedidos-cocina")
    end

    def asignar_tienda
      return if tienda.present?

      derived = derive_tienda_from_actors
      self.tienda = derived if derived
      self.local ||= tienda&.local_para_carrito || autor&.local_activo
    end

    # Bug A: avoid the legacy `cliente.tienda` shim (returns `tiendas.first`)
    # which mis-tagged pedidos for clientes shared across multiple tiendas.
    # Prefer the autor's active tienda, then the usuario's, then fall back to
    # any tienda the cliente belongs to.
    def derive_tienda_from_actors
      candidatos = [autor&.tienda_activa, usuario&.tienda_activa].compact
      cliente = usuario&.cliente || cuenta&.cliente
      return candidatos.first unless cliente

      candidatos.find { |t| cliente.disponible_en?(t) } || cliente.tiendas.first
    end

    def fecha_valida
      return unless !no_validar_fecha && usuario && fecha && !fecha_permitida?

      errors.add :fecha,
                 'inválida, pedidos válidos a partir del ' \
                 "día #{cuenta&.proximo_dia_pedido || usuario&.cliente&.proximo_dia_pedido}. Sábados y Domingos no se cocina."
    end

    def verificar_local
      # Pendiente pedidos are draft carts — local is not required yet (consistent
      # with the other draft-cart validation guards: fecha, cuenta, productos_solicitados).
      return if pendiente?
      # Cancelled pedidos don't need a local — cancellation is terminal.
      return if cancelado?
      # Use the pedido's own tienda (not autor.tienda_activa) so cross-tienda
      # multi-pedido scenarios don't fire this for tiendas without multiple_locales.
      return unless tienda&.multiple_locales? && !local

      errors.add :local,
                 'Debe tener local de venta'
    end

    def direccion_cargada
      # A draft cart (pendiente) may hold envío a domicilio before the user has
      # typed the address — the address is enforced at checkout time
      # (generar_pago_ml / finalizar). Without this guard, selecting "Domicilio
      # Particular" could not be persisted on a pendiente pedido.
      return if pendiente?
      return unless envio_a_domicilio && direccion_envio.blank?

      errors.add :direccion_envio,
                 'inválida, debe contener al menos una palabra'
    end

    def verificar_horario
      return unless !pendiente? && tienda&.horarios_de_entrega && cuenta&.cliente&.horarios_de_entrega? && horario.blank?

      errors.add :horario,
                 'debe seleccionar horario de entrega'
    end

    def asignar_horario
      no_horario = (tienda && !tienda.horarios_de_entrega?) || (cuenta && !cuenta.cliente.horarios_de_entrega?)
      return unless !pendiente? && no_horario && horario.blank?

      self.horario = Pedidos::Horario.where(tienda_id: tienda_id,
                                            predeterminado: true).first
    end

    # Si el cliente no tiene asignado el turno_entrega seleccionado (o no tiene
    # turnos activos), limpiar la referencia para evitar bloquear el checkout
    # con datos viejos heredados de configuraciones previas.
    def limpiar_turno_entrega_invalido
      return if turno_entrega_id.blank?
      return unless cuenta&.cliente

      self.turno_entrega_id = nil unless cuenta.cliente.tiene_turno?(turno_entrega_id)
    end

    def cuando_validar_usuario?
      # Only require a specific usuario when the pedido was created by a cliente
      # user (who always orders for themselves or a specific person within their
      # empresa). Admin/operator-created pedidos are legitimately created for a
      # cuenta without a specific usuario (e.g. bulk admin ordering for an account).
      !pendiente? && !venta_mostrador && !pedido_para_empresa && autor&.cliente?
    end

    def descartar_medios_pago_vacios
      medios_pago.each do |mp|
        mp.mark_for_destruction if mp.importe.blank? || mp.importe.to_f.zero?
      end
    end

    def medios_pago_cubren_total
      # Skip validation when a VM discount is being applied — medios still have
      # pre-discount amounts and will be adjusted after save.
      return if @skip_medios_validation

      active_medios = medios_pago.reject(&:marked_for_destruction?)
      return if active_medios.blank?

      total_medios = active_medios.sum(&:importe).to_f.round(2)
      total_pedido = importe_total.to_f.round(2)
      return if total_medios == total_pedido

      errors.add :base,
                 "El total de medios de pago ($#{'%.2f' % total_medios}) " \
                 "no coincide con el total del pedido ($#{'%.2f' % total_pedido})"
    end

    def rectificar_pedido
      self.confirmation_token = ULID.generate unless confirmation_token
    end
  end
end
