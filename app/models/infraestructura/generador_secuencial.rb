module Infraestructura
  class GeneradorSecuencial < ApplicationRecord
    self.table_name = 'generadores_secuenciales'

    def self.proximo(scope, conditions = {})
      transaction do
        conditions.reverse_merge! scope: scope.to_s
        affected_rows = where(conditions).update_all 'ultimo = ultimo + 1'
        create conditions.merge ultimo: 1 if affected_rows.zero?
        where(conditions).last.ultimo
      end
    rescue ActiveRecord::StatementInvalid
      # Cuando el generador no existe y hay que crearlo se puede producir un deadlock asi que reintento
      sleep rand
      retry
    end
  end
end
