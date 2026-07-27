module Ventas
  module Facturacion
    class Comprobante < Comprobantes::ComprobantePropio
      cargar_eventos "#{__dir__}/eventos"

      has_many :renglones, class_name: 'Ventas::Facturacion::Renglon', dependent: :destroy
      accepts_nested_attributes_for :renglones, allow_destroy: true, reject_if: lambda { |a|
        a['categoria_id'].blank? && a['producto_id'].blank?
      }
      has_many :renglones_afectadores, class_name: 'Ventas::Facturacion::Renglon', foreign_key: :comprobante_afectado_id
      has_many :subtotales, dependent: :destroy, class_name: 'Ventas::Facturacion::Subtotal'
      has_and_belongs_to_many :asociados, class_name: 'Ventas::Facturacion::Comprobante', join_table: :comprobantes_asociados,
                                          association_foreign_key: :asociado_id

      belongs_to :local, class_name: 'Locales::Local', optional: true

      attr_accessor :completar_on_save, :total_sin_imp
      attr_writer :errores_facturacion

      before_validation :cachear_local
      before_save :completar, if: :completar_on_save
      before_save :cachear_descripcion

      before_destroy :verificar_afectados

      validates :cuenta, :tipo, presence: true
      validates :renglones, length: { minimum: 1, message: '^Debería tener al menos 1 renglón' }
      validate :total_positivo
      validate :verificar_local

      scope :del_dia, ->(fecha) { emitidos_en_periodo fecha..fecha }
      scope :emitidos_en_periodo, ->(periodo) { emitidos_desde(periodo.first).emitidos_hasta(periodo.last) }
      scope :manuales, -> { where automatico: false }
      scope :de_tipo, ->(tipo) { where { tipo.split(',').map { |t| type.ends_with t }.reduce(&:|) } }
      scope :ordenados_x_tipo_y_nro, -> { order 'comprobantes.tipo_id, comprobantes.nro' }
      scope :ordenados_x_fecha_tipo_y_nro, lambda {
        order 'comprobantes.fecha_emision, comprobantes.tipo_id, comprobantes.nro'
      }
      scope :notas_credito, -> { where type: 'Ventas::Facturacion::NotaCredito' }
      scope :facturas, -> { where type: 'Ventas::Facturacion::Factura' }
      scope :facturas_y_ncs, -> { de_tipo 'Factura,NotaCredito' }
      scope :con_saldo_pendiente, -> { joins(:movimientos).where('movimientos_cbles.saldo <> 0') }
      scope :que_debitan, -> { joins(:tipo).where('tipos_comprobantes.debitan = true') }
      scope :pendientes_para_afectar, lambda { |cuenta|
        que_debitan.con_saldo_pendiente.where(cuenta_id: cuenta).includes(:movimientos)
      }
      scope :pendientes_para_pagar, ->(cliente) { where(type: 'Ventas::Facturacion::OrdenPago').con_saldo_pendiente.joins(:cuenta).where(cuentas: { cliente_id: cliente.to_i }).includes(:movimientos) }

      def self.nro_completo_eq(num)
        where { nro == num }
      end

      def self.find_by_letra_y_nro(letra, _pv, nro)
        joins(:tipo).where(nro: nro).where { tipo.letra == letra }.readonly(false).first
      end

      def self.find_for_autocomplete(params)
        de_tipo(params[:tipo]).nro_completo_eq(params[:q]).ordenados_x_fecha_tipo_y_nro
      end

      def self.crear(tipoarg, attrs = {})
        tipoarg.split('_').map(&:capitalize).join('::').gsub('Nota::Credito', 'NotaCredito').gsub('Nota::Debito', 'NotaDebito').gsub(
          'Orden::Pago', 'OrdenPago'
        ).to_s.classify.constantize.new attrs
      end

      def total_sin_iva
        renglones.map(&:precio_total).sum
      end

      def total_facturado_con_iva
        subtotales.to_a.sum(&:total_con_iva)
      end

      def subtotales_gravados
        subtotales.select(&:gravado?)
      end

      def subtotal_gravado
        subtotales_gravados.sum(&:base_imponible)
      end

      def subtotal_no_gravado
        subtotales.select(&:no_gravado?).sum(&:base_imponible)
      end

      def subtotal_gravado_con_iva
        subtotales_gravados.sum(&:total_con_iva)
      end

      def subtotal
        subtotales.to_a.sum(&:base_imponible)
      end

      def subtotal_de_tasa_iva(tasa_iva)
        subtotales.find { |s| s.tasa_iva == tasa_iva }.try(:base_imponible)
      end

      def gravado_de_tasa_iva(tasa_iva)
        subtotales.find { |s| s.tasa_iva == tasa_iva }.try(:iva)
      end

      def total_iva
        subtotales.to_a.sum(&:iva)
      end

      def monto_percibido
        percepciones.to_a.sum(&:monto)
      end

      def pendiente?
        en_estado? :pendiente
      end

      def confirmado?
        en_estado? :confirmado
      end

      def vencido?
        fecha_vencimiento && fecha_vencimiento < Time.zone.today
      end

      def nro_completo
        if pendiente?
          'Por Asignar'
        else
          "#{tipo.formato_corto} #{nro}"
        end
      end

      def nro_formateado
        format('%08d', nro.to_i)
      end

      def descripcion
        super or cachear_descripcion
      end

      alias to_s nro_completo

      def descripcion_y_saldo
        "#{descripcion} | #{saldo}"
      end

      def saldo
        movimientos.last ? movimientos.last.saldo : total
      end

      def to_s_full
        nro_completo.to_s
      end

      def to_console
        lineas = []
        lineas << "ID: #{id} | Fecha: #{fecha_emision}"
        lineas << "Cuenta: #{cuenta.nro_y_nombre}"
        renglones.each { |r| lineas << r.to_console }
        lineas << "Subtotales: #{subtotales.map(&:base_imponible).join ', '}"
        "#{lineas.join("\n")}\n\n"
      end

      def factura?
        false
      end

      def nota_debito?
        false
      end

      def nota_credito?
        false
      end

      def orden_pago?
        false
      end

      def completar
        calcular_totales
      end

      def completar!
        completar.save!
      end

      def calcular_totales(_calcular_percepciones = true)
        self.subtotales = calcular_subtotales
        self.total = total_facturado_con_iva
        self
      end

      def para_resp_inscripto?
        cuenta.cliente.resp_inscripto?
      end

      def mostrar_total_renglon_con_iva?
        !mostrar_subtotales?
      end

      def mostrar_subtotales?
        true
      end

      def confirmable?(user)
        user.admin? && pendiente?
      end

      def manual?
        !automatico?
      end

      def clonar(opciones = {})
        super(opciones.reverse_merge shallow: [:cuenta, :pedido])
      end

      def renglones_en_papel
        renglones
      end

      def eliminar
        destroy
      end

      def tasas_iva
        subtotales.map(&:tasa_iva)
      end

      def mostrar_despacho?
        despachos.any?
      end

      def despachos
        renglones.map(&:despacho).compact.uniq
      end

      def no_gravado?
        true
      end

      delegate :empty?, to: :renglones

      def cancela_a=(cbte)
        self.afectados = [cbte].compact
      end

      def cancela_a
        afectados.first if afectados.size == 1
      end

      def cancela_a_id=(id)
        self.afectado_ids = [id]
      end

      def cancela_a_id
        cancela_a.try(:id)
      end

      def debita?
        factura? or nota_debito?
      end

      def acredita?
        !debita?
      end

      def nota?
        false
      end

      def generar_afectaciones; end

      def determinar_letra
        'C'
      end

      def self.para_cancelar(cbte)
        new.preparar_para_cancelar_a cbte, cbte.renglones.map(&:clonar)
      end

      def preparar_para_cancelar_a(cbte, renglones_nuevos, copiar_encabezado_de = cbte)
        self.cancela_a = cbte
        copy_fields_from copiar_encabezado_de, ['pedido', 'cuenta', 'automatico', 'fecha_emision']
        self.renglones = renglones_nuevos
        self
      end

      def saldado?
        saldo.zero?
      end

      def refacturar(_tipo = nil)
        a_refacturar = renglones.all
        a_refacturar.each do |r|
          producto = r.producto
          r.producto = producto
          r.descripcion = producto.nombre
          r.precio_unitario = producto.buscar_precio(cuenta.cliente, pedido.fecha)
        end
        calcular_totales
        movimientos.clear
        contabilizar
        save
      end

      private

      def calcular_subtotales
        renglones.each { |r| r.ajustar_tasa_iva self }.group_by(&:tasa_iva).map do |tasa, rs|
          Subtotal.new(comprobante: self, tasa_iva: tasa, base_imponible: rs.sum(&:precio_total)).tap do |st|
            st.iva = para_resp_inscripto? ? st.base_imponible * st.tasa_iva.alicuota! : rs.to_a.sum(&:iva_total)
          end
        end
      end

      def verificar_afectados
        raise ErrorAplicacion, 'Comprobante tiene afectaciones relacionadas' if afectados.present?
      end

      def total_positivo
        errors.add :total, 'debe ser positivo' unless total.to_f >= 0
      end

      def verificar_local
        return unless autor&.tienda_activa&.multiple_locales? && !local

        errors.add :local,
                   'Debe tener local de venta'
      end

      def cachear_descripcion
        self.descripcion = nro_completo.to_s if tipo
      end

      def cachear_local
        return if local

        self.local = pedido&.local ||
                     cancela_a&.local ||
                     autor&.local_activo ||
                     tienda&.local_para_carrito
      end
    end
  end
  ['factura', 'nota_credito', 'nota_debito', 'orden_pago'].each { |dep| require_dependency "#{__dir__}/#{dep}" }
end
