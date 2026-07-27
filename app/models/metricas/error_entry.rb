module Metricas
  class ErrorEntry < ApplicationRecord
    self.table_name = 'metricas_errors'

    validates :fecha, presence: true

    scope :recientes, ->(n = 20) { order(fecha: :desc).limit(n) }
    scope :del_dia, ->(date) { where('DATE(fecha) = ?', date) }
  end
end
