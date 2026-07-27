module Pedidos
  class PedidoMultiple < ApplicationRecord
    MAX_PEDIDOS = 10

    belongs_to :usuario, class_name: 'Usuarios::Usuario', optional: true
    belongs_to :cuenta, class_name: 'Clientes::Cuenta', optional: true
    has_many :pedidos, class_name: 'Pedidos::Pedido', dependent: :nullify
    has_many :pagos_electronicos, class_name: 'Ventas::Facturacion::PagoElectronico', dependent: :nullify

    # Groups with at least one pendiente (estado=1) child pedido. Used by the
    # cart dropdown to surface a cross-tienda group from any tienda the user
    # is browsing.
    scope :abiertos, lambda {
      where(id: Pedidos::Pedido.where(estado_id: 1).select(:pedido_multiple_id))
    }

    def abierto?
      Pedidos::Pedido.uncached do
        Pedidos::Pedido.exists?(pedido_multiple_id: id, estado_id: 1)
      end
    end

    validate :usuario_o_cuenta_presente
    validate :pedidos_belong_to_owner

    ESTADOS = { abierto: 0, pagando: 1, pagado: 2 }.freeze

    # Simple estado helpers without Rails enum (avoids Rails 7.1 class_name requirement)
    ESTADOS.each do |nombre, valor|
      define_method(:"#{nombre}?") { estado == valor }
      define_method(:"#{nombre}!") { update!(estado: valor) }
    end

    validate :max_pedidos_limit, on: :add_pedido

    def total
      Danconia::Money.new(pedidos.sum { |p| p.importe_total.to_f })
    end

    def pedidos_pendientes
      pedidos.select { |p| p.estado_id == 1 }
    end

    def todos_confirmados?
      pedidos.all? { |p| p.estado_id == 2 }
    end

    def external_reference(uid = nil)
      uid ||= usuario_id || cuenta_id
      "multiple-#{id}-#{uid}"
    end

    def single?
      pedidos.count <= 1
    end

    private

    def max_pedidos_limit
      errors.add(:base, "No se pueden agregar más de #{MAX_PEDIDOS} pedidos") if pedidos.size >= MAX_PEDIDOS
    end

    def usuario_o_cuenta_presente
      errors.add(:base, 'Debe tener un usuario o una cuenta') if usuario_id.nil? && cuenta_id.nil?
    end

    # SECURITY (incident 2026-05-17 PM 78): defense-in-depth so no pedido owned
    # by another user can ever be attached to this group, even if a future
    # controller bug forgets to filter. When usuario_id is set the group is
    # single-user (admin can still author pedidos for their own employees:
    # autor_id matches). When only cuenta_id is set (admin-empresa shared
    # bucket) all pedidos must share the cuenta.
    def pedidos_belong_to_owner
      pedidos.each do |p|
        next if usuario_id.present? && (p.autor_id == usuario_id || p.usuario_id == usuario_id)
        next if usuario_id.nil? && cuenta_id.present? && p.cuenta_id == cuenta_id

        errors.add(:base, "Pedido #{p.id || '(nuevo)'} no pertenece al dueño del grupo")
      end
    end
  end
end
