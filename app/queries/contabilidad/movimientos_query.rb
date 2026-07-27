module Contabilidad
  class MovimientosQuery < ApplicationQuery
    extend Memoist

    attr_accessor :user, :cuentas_ids, :clientes_ids, :usuarios_ids

    attribute :visualizar_por_id, Integer, default: 2
    validates :user, presence: true
    attribute :desde, Date
    attribute :hasta, Date
    validates :desde, :hasta, date: true, allow_nil: true

    def relation
      q = Movimiento.joins(:cuenta)
      q = q.where(tienda_id: user.tienda_activa.id)
      q = q.joins(:comprobante).merge(Comprobantes::Comprobante.emitidos_desde(desde)) if desde.present?
      q = q.joins(:comprobante).merge(Comprobantes::Comprobante.emitidos_hasta(hasta)) if hasta.present?
      q = q.joins(:comprobante).where(comprobantes: { local_id: user.local_activo.id }) if user.tienda_activa.multiple_locales && user.local_activo
      q = q.none if user.blank?
      cuentas_auxs = !user.admin? && user.cumple_rol?(:administrador_empresa) ? user.cuenta.cliente.cuentas.map(&:id) : cuentas.map(&:id)
      q = q.where(cuentas: { id: cuentas_auxs }) if cuentas_auxs.present?
      filtros_clientes(q)
    end

    def filtros_clientes(q)
      q = q.where(cuentas: { cliente_id: clientes.map(&:id) }) if clientes.present?
      q = q.joins(comprobante: :pedido).where(pedidos: { usuario_id: usuarios.ids }) if usuarios.present?
      q
    end

    def clientes
      return if clientes_ids.blank?

      user.cliente? ? [user.cliente] : Clientes::Cliente.active.where(id: clientes_ids.to_s.split(','))
    end
    memoize :clientes

    def usuarios
      return if usuarios_ids.blank?

      user.cliente? ? user.cliente.usuarios.where(usuarios_ids.to_s.split(',')) : Usuarios::Usuario.where(id: usuarios_ids.to_s.split(','))
    end
    memoize :usuarios

    def cuentas
      return [] if cuentas_ids.blank?

      Clientes::Cuenta.where(id: cuentas_ids.to_s.split(','))
    end
    memoize :cuentas
  end
end
