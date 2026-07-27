module Clientes
  class ClientesQuery < ApplicationQuery
    attr_accessor :cliente_ids, :cuenta_ids, :cuit, :email, :activo, :user,
                  :horarios_de_corte_ids, :horario_corte_cliente_ids, :horario_corte_cuenta_ids

    validates :user, presence: true

    def relation
      # Shared-clientes migration (Step 2): scope by the clientes_tiendas HABTM
      # instead of the legacy clientes.tienda_id column. Today these match 1:1
      # because the after_save callback backfills the join, but this query is
      # already future-proof for when tienda_id is dropped and clientes are
      # explicitly linked into multiple tiendas.
      q = Cliente.includes(:cuentas)
                 .joins(:tiendas)
                 .where(tiendas: { id: user.tienda_activa.id })
                 .order(:nombre)
      # Filter by cliente IDs (from select2 remote)
      if cliente_ids.present?

        cl_ids = cliente_ids.is_a?(String) ? cliente_ids.split(',').map(&:to_i) : cliente_ids
        q = q.where(id: cl_ids)
      end

      # Filter by cuenta IDs (from select2 remote)
      if cuenta_ids.present?
        c_ids = cuenta_ids.is_a?(String) ? cuenta_ids.split(',').map(&:to_i) : cuenta_ids
        q = q.joins(:cuentas).where(cuentas: { id: c_ids })
      end

      # Filter by CUIT
      q = q.where('clientes.cuit LIKE ?', "%#{cuit}%") if cuit.present?

      # Filter by email
      q = q.where('clientes.email LIKE ?', "%#{email}%") if email.present?

      # Filter by effective hora_corte (cuenta override > cliente fallback)
      if horarios_de_corte_ids.present?
        hc_values = (horarios_de_corte_ids.is_a?(String) ? horarios_de_corte_ids.split(',') : horarios_de_corte_ids).compact_blank
        if hc_values.any?
          q = q.joins(:cuentas)
               .where("COALESCE(NULLIF(cuentas.horario_corte_pedidos, ''), clientes.horario_corte_pedidos) IN (?)", hc_values)
        end
      end

      # Filter by cliente horario_corte_pedidos
      if horario_corte_cliente_ids.present?
        hc_values = (horario_corte_cliente_ids.is_a?(String) ? horario_corte_cliente_ids.split(',') : horario_corte_cliente_ids).compact_blank
        q = q.where(clientes: { horario_corte_pedidos: hc_values }) if hc_values.any?
      end

      # Filter by cuenta horario_corte_pedidos (override on cuentas)
      if horario_corte_cuenta_ids.present?
        hc_values = (horario_corte_cuenta_ids.is_a?(String) ? horario_corte_cuenta_ids.split(',') : horario_corte_cuenta_ids).compact_blank
        q = q.joins(:cuentas).where(cuentas: { horario_corte_pedidos: hc_values }) if hc_values.any?
      end

      # Filter by activo status
      case activo
      when 'true', 'active'
        q = q.active
      when 'false', 'inactive'
        q = q.inactive
      end

      q.distinct
    end
  end
end
