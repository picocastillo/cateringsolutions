class AddIndexComprobantesOnTiendaEstadoTypeFechaEmision < ActiveRecord::Migration[7.1]
  def change
    add_index :comprobantes, [:tienda_id, :estado_id, :type, :fecha_emision],
              name: 'idx_comprobantes_tienda_estado_type_fecha_emision'
  end
end
