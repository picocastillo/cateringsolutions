module Usuarios
  class UsuariosQuery < ApplicationQuery
    attr_accessor :login, :nombre, :status, :tipo, :user, :legajo, :dni, :cuenta_ids, :cliente_ids, :tipo_id

    attribute :roles, Array, default: []
    validates :user, presence: true

    def relation
      self.status = :all if status.blank?
      q = Usuario.includes(cuenta: :cliente).order(:login).status(status).visibles_por(user)
      # Shared-clientes migration (Step 2): include
      #   - admin users (cuenta_id IS NULL), AND
      #   - cliente users whose cliente is linked to the active tienda via the
      #     clientes_tiendas HABTM (covers both legacy single-tienda clientes and
      #     newly shared multi-tienda clientes).
      tienda_id = user.tienda_activa.id
      cliente_ids_visibles = Clientes::Cliente.joins(:tiendas)
                                              .where(tiendas: { id: tienda_id })
                                              .select(:id)
      q = q.where(
        'usuarios.cuenta_id IS NULL OR usuarios.cuenta_id IN (?)',
        Clientes::Cuenta.where(cliente_id: cliente_ids_visibles).select(:id)
      )
      q = q.where(usuarios: { login: login }) if login.present?
      q = q.where(usuarios: { legajo: legajo }) if legajo.present?
      q = q.where(usuarios: { dni: dni }) if dni.present?
      q = q.where('usuarios.nombre like ?', "%#{nombre}%") if nombre.present?
      q = q.cumple_roles roles if roles.any?
      q = filtrar_por_tipo q if tipo.present?
      if user.cliente?
        q = q.joins(cuenta: :cliente).where('clientes.id =?', user.cuenta.cliente)

      else
        q = q.where(cuenta_id: cuenta_ids.split(',').map(&:to_i)) if cuenta_ids.present?
        q = q.joins(:cuenta).where(cuentas: { cliente_id: cliente_ids.split(',').map(&:to_i) }) if cliente_ids.present?
        if tipo_id.present?
          q = tipo_id.to_i == 1 ? q.where.not(usuarios: { cuenta_id: nil }) : q.where(usuarios: { cuenta_id: nil })
        end
      end
      q
    end

    private

    def filtrar_por_tipo(q)
      if tipo == 'Cliente'
        q.where.not cuenta_id: nil
      else
        q.where cuenta_id: nil
      end
    end
  end
end
