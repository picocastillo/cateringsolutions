module Clientes
  class Cliente < ApplicationRecord
    acts_as_discontinued

    validates :nombre, presence: true
    # NOTE: per-tienda uniqueness scope was dropped in Step 8 along with the
    # `tienda_id` column. A global uniqueness validation will be re-introduced
    # in Step 9 once the dedup migration consolidates duplicate clientes.

    validates :dia_inicio_ciclo_facturacion, :vencimiento_a, presence: true

    validates :dia_inicio_ciclo_facturacion, numericality: { less_than: 29 }
    validates :dia_inicio_ciclo_facturacion, numericality: { greater_than: 0 }
    validates :vencimiento_a, numericality: { greater_than: -1 }
    validates :vencimiento_a, numericality: { less_than: 31 }

    validates :cuit, cuit: true

    validate :horario_corte

    after_create :crear_cuentas

    has_and_belongs_to_many :categorias, class_name: 'Productos::Categoria', join_table: 'clientes_categorias',
                                         association_foreign_key: 'categoria_id', order: 'categorias.nombre'

    has_and_belongs_to_many :precios, class_name: 'Productos::Precio', join_table: 'clientes_precios',
                                      association_foreign_key: 'precio_id', order: 'precio.nombre'

    # Step 8 of shared-clientes migration: the legacy `belongs_to :tienda`
    # column was dropped. Clientes are now attached to one or more tiendas
    # exclusively through the `clientes_tiendas` HABTM.
    has_and_belongs_to_many :tiendas, class_name: 'Tiendas::Tienda', join_table: 'clientes_tiendas',
                                      association_foreign_key: 'tienda_id'

    # Legacy compatibility shim: callers that still read `cliente.tienda` get
    # the cliente's first attached tienda (typically the only one for
    # single-tienda clientes). Prefer `cliente.tiendas` in new code.
    def tienda
      tiendas.first
    end

    # Legacy writer: `cliente.tienda = t` (and `Cliente.new(tienda: t)`) used to
    # set the dropped `tienda_id` belongs_to. Now it replaces the HABTM list
    # with a single-tienda set so existing call sites keep working.
    def tienda=(tienda)
      self.tiendas = Array(tienda).compact
    end

    def disponible_en?(tienda)
      return false unless tienda

      if persisted?
        tiendas.exists?(id: tienda.id)
      else
        # Unsaved records have no FK yet, so `tiendas.exists?` would query
        # `WHERE clientes_tiendas.cliente_id IS NULL` and always return false.
        # Fall back to checking the in-memory association so authorization
        # rules work correctly on `Cliente.new(tiendas: [tienda_activa])`.
        tiendas.to_a.any? { |t| t.id == tienda.id }
      end
    end

    def multi_tienda?
      tiendas.many?
    end

    # Cleaner replacement for the legacy `where(tienda_id: x)` scope: returns
    # clientes that are linked to the given tienda via clientes_tiendas.
    scope :disponibles_en, ->(tienda) { joins(:tiendas).where(tiendas: { id: tienda }).distinct }

    has_many :cuentas, -> { order :position }, dependent: :destroy, class_name: 'Clientes::Cuenta', autosave: true, after_add: ->(t, i) { i.cliente = t }
    accepts_nested_attributes_for :cuentas, allow_destroy: true

    has_many :usuarios, through: :cuentas, class_name: 'Usuarios::Usuario'
    has_many :pedidos, through: :cuentas, class_name: 'Pedidos::Pedido'

    has_many :clientes_turnos_entrega, class_name: 'Pedidos::ClienteTurnoEntrega', dependent: :destroy
    has_many :turnos_entrega, through: :clientes_turnos_entrega, source: :turno_entrega, class_name: 'Pedidos::TurnoEntrega'

    def cuentas_activas
      cuentas.select(&:active?)
    end

    def self.confirmar_pedidos_aceptados
      # Single query: find all aceptado pedidos whose fecha is before the cuenta's effective cutoff.
      # Cutoff logic: if current time >= hora_corte, cutoff is tomorrow (skip weekends); otherwise today.
      # The COALESCE picks cuenta hora_corte first, falls back to cliente hora_corte.
      pedido_ids = Pedidos::Pedido
                   .joins(cuenta: :cliente)
                   .merge(Clientes::Cliente.active)
                   .where(pedidos: { estado_id: 2 })
                   .where(<<~SQL.squish)
                     pedidos.fecha < CASE
                       WHEN CURTIME() >= STR_TO_DATE(
                         COALESCE(NULLIF(cuentas.horario_corte_pedidos, ''), clientes.horario_corte_pedidos), '%H:%i')
                       THEN
                         CASE DAYOFWEEK(CURDATE() + INTERVAL 1 DAY)
                           WHEN 1 THEN CURDATE() + INTERVAL 2 DAY
                           WHEN 7 THEN CURDATE() + INTERVAL 3 DAY
                           ELSE CURDATE() + INTERVAL 1 DAY
                         END
                       ELSE
                         CASE DAYOFWEEK(CURDATE())
                           WHEN 1 THEN CURDATE() + INTERVAL 1 DAY
                           WHEN 7 THEN CURDATE() + INTERVAL 2 DAY
                           ELSE CURDATE()
                         END
                     END
                   SQL
                   .limit(500)
                   .pluck(:id)

      pedido_ids.each { |pid| Clientes::ConfirmarJob.perform_later(pid) }
    end

    def cuenta_principal
      cuentas_activas[0]
    end

    def estado_cuenta_corriente(usuario)
      Contabilidad::SaldosMovimientosQuery.new(user: usuario, visualizar_por_id: 1, clientes_ids: id.to_s).first
    end

    def to_s
      nombre
    end

    def usuarios_alcanzados
      usuarios
    end

    def precios_vigentes(fecha, tienda_activa)
      f = fecha.to_date
      prs = Productos::Precio
            .joins('left join clientes_precios cp on cp.precio_id=precios.id')
            .where('precios.fecha_desde <= ? and (precios.fecha_hasta >= ? or precios.fecha_hasta is null)', f, f)
            .where('cp.cliente_id is null or cp.cliente_id = ?', id)
            .joins(producto: :categoria)
            .where(productos: { tienda_id: tienda_activa.id })
            .merge(Productos::Producto.active)
            .where(productos: {
                     categoria_id: Productos::Categoria.where(tienda_id: tienda_activa.id).active.select(:id)
                   })
            .where.not(productos: {
                         categoria_id: Productos::Categoria.where(tienda_id: tienda_activa.id)
                                       .where(menu_diario: true).select(:id)
                       })
            .includes(:clientes, producto: [:categoria, :imagenes, :stocks])
      prs = prs.where(productos: { categoria_id: categorias.map(&:id) }) if categorias.present?
      prs
    end

    def resp_inscripto?
      true
    end

    def fecha_vencimiento(f = Time.current)
      f = if f.day >= dia_inicio_ciclo_facturacion
            1.month.since.change(day: dia_inicio_ciclo_facturacion).to_date
          else
            f.change(day: dia_inicio_ciclo_facturacion).to_date
          end
      f + (vencimiento_a - 1).days
    end

    def hora_corte
      horario_corte_pedidos.split(':')[0]
    end

    def corte=(h)
      self.horario_corte_pedidos = "#{h.split(':')[0]}:#{h.split(':')[1]}"
    end

    def corte
      "#{hora_corte}:#{minuto_corte}"
    end

    def minuto_corte
      horario_corte_pedidos.split(':')[1]
    end

    def dia_filtro
      1.month.ago.change(day: dia_inicio_ciclo_facturacion).to_date
    end

    def proximo_dia_pedido
      h = Time.current
      f = hora_corte.to_i > h.hour || (hora_corte.to_i == h.hour && minuto_corte.to_i > h.min) ? Time.zone.today : Time.zone.today + 1.day
      if f.sunday?
        (f + 1.day)
      elsif f.saturday?
        (f + 2.days)
      else
        f
      end
    end

    def turnos_activos
      turnos_entrega.activos.ordenados
    end

    def tiene_turno?(turno_id)
      turnos_entrega.exists?(id: turno_id)
    end

    private

    def crear_cuentas
      return unless cuentas.empty?

      cuentas << Clientes::Cuenta.create(cliente: self)
    end

    def horario_corte
      if horario_corte_pedidos
        if horario_corte_pedidos.split(':')[0].to_i > 23 || horario_corte_pedidos.split(':')[0].to_i.negative?
          errors.add :horario_corte_pedidos,
                     'Hora no valida (HORA INVALIDA, 0 A 23).'
        end
        if horario_corte_pedidos.split(':')[1].to_i > 59 || horario_corte_pedidos.split(':')[1].to_i.negative?
          errors.add :horario_corte_pedidos,
                     'Hora no valida (MINUTOS INVALIDOS, 0 A 59).'
        end
      else
        errors.add :horario_corte_pedidos, 'Debe asignar horario de corte de toma de pedidos.'
      end
    end
  end
end
