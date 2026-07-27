class CreateMetricasTables < ActiveRecord::Migration[5.2]
  def change
    create_table :metricas_snapshots do |t|
      t.date :fecha, null: false
      t.integer :total_requests, default: 0
      t.integer :requests_mobile, default: 0
      t.integer :requests_desktop, default: 0
      t.integer :requests_unknown, default: 0
      t.decimal :avg_response_time_ms, precision: 8, scale: 2, default: 0
      t.decimal :p95_response_time_ms, precision: 8, scale: 2, default: 0
      t.decimal :max_response_time_ms, precision: 8, scale: 2, default: 0
      t.integer :status_2xx, default: 0
      t.integer :status_3xx, default: 0
      t.integer :status_4xx, default: 0
      t.integer :status_5xx, default: 0
      t.integer :unique_ips, default: 0
      t.text :top_endpoints
      t.text :top_ips
      t.text :response_times_histogram
      t.text :requests_by_hour
      t.decimal :db_total_size_mb, precision: 10, scale: 2, default: 0
      t.text :db_table_sizes
      t.integer :db_active_connections, default: 0
      t.integer :db_max_connections, default: 0
      t.text :db_slow_queries
      t.timestamps
    end

    add_index :metricas_snapshots, :fecha, unique: true

    create_table :metricas_errors do |t|
      t.datetime :fecha, null: false
      t.string :error_class
      t.text :error_message
      t.string :controller_action
      t.integer :status_code
      t.string :ip
      t.string :url
      t.datetime :created_at, null: false
    end

    add_index :metricas_errors, :fecha
    add_index :metricas_errors, :error_class
  end
end
