class AddMissingIndexesToClientesQuery < ActiveRecord::Migration[7.1]
  def change
    # ORDER BY clientes.nombre is executed on every index page load.
    # Without this index MariaDB does a filesort over the entire clientes table.
    add_index :clientes, :nombre, name: 'index_clientes_on_nombre'

    # clientes.horario_corte_pedidos is used in two query filters:
    #   WHERE clientes.horario_corte_pedidos IN (...)
    #   COALESCE(NULLIF(cuentas.horario_corte_pedidos,''), clientes.horario_corte_pedidos) IN (...)
    add_index :clientes, :horario_corte_pedidos,
              name: 'index_clientes_on_horario_corte_pedidos'

    # cuentas.horario_corte_pedidos is used in the same two filters
    # (the COALESCE path and the direct cuenta filter).
    add_index :cuentas, :horario_corte_pedidos,
              name: 'index_cuentas_on_horario_corte_pedidos'
  end
end
