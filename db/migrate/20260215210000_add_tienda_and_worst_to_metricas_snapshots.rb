class AddTiendaAndWorstToMetricasSnapshots < ActiveRecord::Migration[5.2]
  def change
    add_column :metricas_snapshots, :tienda_id, :integer, after: :fecha
    add_column :metricas_snapshots, :worst_response_times, :text, after: :response_times_histogram

    # Change unique index from fecha alone to (fecha, tienda_id)
    remove_index :metricas_snapshots, :fecha
    add_index :metricas_snapshots, [:fecha, :tienda_id], unique: true, name: 'idx_metricas_fecha_tienda'
    add_index :metricas_snapshots, :tienda_id
  end
end
