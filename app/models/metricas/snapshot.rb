module Metricas
  class Snapshot < ApplicationRecord
    self.table_name = 'metricas_snapshots'

    belongs_to :tienda, class_name: 'Tiendas::Tienda', optional: true

    validates :fecha, presence: true
    validates :fecha, uniqueness: { scope: :tienda_id }

    serialize :top_endpoints, JSON
    serialize :top_ips, JSON
    serialize :response_times_histogram, JSON
    serialize :worst_response_times, JSON
    serialize :delayed_jobs_stats, JSON
    serialize :requests_by_hour, JSON
    serialize :db_table_sizes, JSON
    serialize :db_slow_queries, JSON

    scope :ultimos_dias, ->(n) { where(fecha: n.days.ago.to_date..).order(fecha: :asc) }
    scope :for_fecha, ->(date) { find_by(fecha: date) }
    scope :globales, -> { where(tienda_id: nil) }
    scope :para_tienda, ->(tid) { where(tienda_id: tid) }
  end
end
