module Clientes
  class Cuenta < ApplicationRecord
    acts_as_list scope: :cliente
    acts_as_discontinued

    validates :nombre, presence: true
    validates :nombre, uniqueness: { scope: :cliente_id, case_sensitive: false }

    belongs_to :cliente, class_name: 'Clientes::Cliente'
    has_many :comprobantes, class_name: 'Ventas::Facturacion::Comprobante', dependent: :destroy
    has_many :usuarios, class_name: 'Usuarios::Usuario'

    has_many :pedidos, class_name: 'Pedidos::Pedido'

    validates :nro, presence: true
    # Globally unique after Step 7 (renumber_cuentas_globally) reissued every nro
    # via the `cuentas_globales` generator and Step 8 backed it with a unique DB index.
    validates :nro, uniqueness: true
    validate :validar_horario_corte

    scope :clientes, -> { joins(:cliente).where { cliente.type == 'Clientes::Cliente' } }

    # Returns distinct effective hora_corte values for a tienda (cuenta override > cliente fallback)
    def self.horarios_corte_efectivos(tienda_id)
      joins(cliente: :tiendas)
        .where(tiendas: { id: tienda_id })
        .merge(Clientes::Cliente.active)
        .pluck(Arel.sql("DISTINCT COALESCE(NULLIF(cuentas.horario_corte_pedidos, ''), clientes.horario_corte_pedidos)"))
        .compact
        .sort
    end

    # Returns distinct horario_corte_pedidos values set directly on clientes
    def self.horarios_corte_clientes(tienda_id)
      joins(cliente: :tiendas)
        .where(tiendas: { id: tienda_id })
        .merge(Clientes::Cliente.active)
        .pluck(Arel.sql('DISTINCT clientes.horario_corte_pedidos'))
        .compact
        .compact_blank
        .sort
    end

    # Returns distinct horario_corte_pedidos values set directly on cuentas (overrides only)
    def self.horarios_corte_cuentas(tienda_id)
      joins(cliente: :tiendas)
        .where(tiendas: { id: tienda_id })
        .merge(Clientes::Cliente.active)
        .where.not(cuentas: { horario_corte_pedidos: [nil, ''] })
        .pluck(Arel.sql('DISTINCT cuentas.horario_corte_pedidos'))
        .compact
        .sort
    end

    before_validation :asignar_nro

    def nombre_y_alternativas
      to_s + (cliente.cuentas.size == 1 ? '' : " (#{cliente.cuentas.map(&:nro).join(', ')})")
    end

    def destroy
      unless comprobantes.where(estado_id: 2).empty?
        raise ErrorAplicacion,
              "No se puede eliminar Cuenta #{to_s_full} por poseer comprobantes asociados.".html_safe
      end

      super
    end

    # cuenta_corriente_parcial overrides cliente if set (true/false),
    # falls back to cliente.cuenta_corriente when nil (like horario_corte_pedidos)
    def cuenta_corriente_habilitada?
      if cuenta_corriente_parcial.nil?
        cliente&.cuenta_corriente?
      else
        cuenta_corriente_parcial?
      end
    end

    def to_s_full
      opciones = []
      opciones << nombre if nombre.present?
      opciones << "Desactivada el #{discontinued_at.to_fs(:short)}" if inactive?
      nro.to_s + (opciones.any? ? %{ <small>(#{opciones.join(', ')})</small>} : '')
    end

    def nro_y_nombre
      format('%04d - %s', nro.to_i, nombre)
    end

    def cliente_y_nombre
      if nombre.present? && nombre != cliente.nombre
        format('%s - %s', nombre,
               cliente.nombre)
      else
        format('%s', cliente.nombre)
      end
    end

    def cliente_y_sucursal
      cliente.to_s
    end

    def to_s
      if cliente.to_s == nombre || nombre.blank?
        cliente.to_s
      else
        format('%s - %s', cliente, nombre)
      end
    end

    def serializable_hash(_options = nil)
      super(only: [:id, :nombre, :nro], methods: [:nro_y_nombre, :cliente_y_nombre])
    end

    def listas_precios
      cliente.listas_precios.select { |l| l.determinar_cuenta_aplicada(cliente: cliente) == self }
    end

    # Returns the effective horario_corte_pedidos: cuenta's own if set, otherwise cliente's
    def hora_corte_efectiva
      horario_corte_pedidos.presence || cliente.horario_corte_pedidos
    end

    def hora_corte
      hora_corte_efectiva.split(':')[0]
    end

    def minuto_corte
      hora_corte_efectiva.split(':')[1]
    end

    def corte
      "#{hora_corte}:#{minuto_corte}"
    end

    def corte=(h)
      self.horario_corte_pedidos = h.present? ? "#{h.split(':')[0]}:#{h.split(':')[1]}" : nil
    end

    def proximo_dia_pedido
      h = Time.current
      f = hora_corte.to_i > h.hour || (hora_corte.to_i == h.hour && minuto_corte.to_i > h.min) ? Time.zone.today : Time.zone.today + 1.day
      if f.sunday?
        f + 1.day
      elsif f.saturday?
        f + 2.days
      else
        f
      end
    end

    def horas_restantes_al_corte
      ahora = Time.current
      dia_corte = proximo_dia_pedido
      hora_corte_time = Time.zone.parse("#{dia_corte} #{hora_corte_efectiva}")
      # For 00:00 cutoff, it means end of previous day (23:59)
      hora_corte_time -= 1.minute if hora_corte_efectiva == '00:00'
      segundos = (hora_corte_time - ahora).to_f
      (segundos / 3600).round
    end

    def fecha_permitida?(fecha, autor)
      fnv = true
      if !autor.admin? && fecha
        pd = proximo_dia_pedido
        fnv = pd <= fecha && !fecha.saturday? && !fecha.sunday?
      end
      fnv || autor.admin?
    end

    # Returns hora_corte string for a given turno
    # Almuerzo: uses cuenta/cliente hora_corte_efectiva
    # Desayuno/Merienda: uses turno's hora_corte
    def hora_corte_para_turno(turno)
      return nil unless turno

      if turno.codigo == 'almuerzo'
        hora_corte_efectiva || '11:00'
      else
        turno.hora_corte_formateada
      end
    end

    # Calculates next order date based on turno-specific hora_corte
    def proximo_dia_pedido_para_turno(turno)
      return proximo_dia_pedido unless turno

      hora_corte_str = hora_corte_para_turno(turno)
      hora, minuto = hora_corte_str.split(':').map(&:to_i)

      h = Time.current
      f = hora > h.hour || (hora == h.hour && minuto > h.min) ? Time.zone.today : Time.zone.today + 1.day

      if f.sunday?
        f + 1.day
      elsif f.saturday?
        f + 2.days
      else
        f
      end
    end

    def asignar_nro
      self.nombre = (cliente ? cliente.nombre : 'Principal') if nombre.blank?
      return unless nro.blank? && cliente

      # Step 4 + Step 7 of shared-clientes migration: cuenta numbering is GLOBAL
      # across all tiendas. The scope name was bumped to 'cuentas_globales' so
      # the counter starts fresh, after a one-shot renumber migration
      # (20260425_renumber_cuentas_globally) reissued nros for all existing rows
      # in id-asc order. Legacy scopes:
      #   - 'cuentas_contables'                       (Step 4 attempt, also retired)
      #   - "tienda#{cliente.tienda.id}_cuentas_contables" (per-tienda original)
      self.nro = Infraestructura::GeneradorSecuencial.proximo('cuentas_globales')
    end

    private

    def validar_horario_corte
      return if horario_corte_pedidos.blank?

      parts = horario_corte_pedidos.split(':')
      if parts.size != 2
        errors.add :horario_corte_pedidos, 'Hora no válida (formato HH:MM).'
        return
      end

      hora = parts[0].to_i
      minuto = parts[1].to_i

      errors.add :horario_corte_pedidos, 'Hora no válida (HORA INVÁLIDA, 0 A 23).' if hora > 23 || hora.negative?
      return unless minuto > 59 || minuto.negative?

      errors.add :horario_corte_pedidos, 'Hora no válida (MINUTOS INVÁLIDOS, 0 A 59).'
    end
  end
end
