module Metricas
  class DbAnalyzer
    def self.collect
      conn = ActiveRecord::Base.connection
      db_name = conn.current_database

      # Table sizes from information_schema
      table_sizes = conn.select_all(<<~SQL.squish).to_a
        SELECT table_name,
               table_rows,
               ROUND(data_length / 1024 / 1024, 2) AS data_mb,
               ROUND(index_length / 1024 / 1024, 2) AS index_mb
        FROM information_schema.tables
        WHERE table_schema = #{conn.quote(db_name)}
          AND table_type = 'BASE TABLE'
        ORDER BY data_length + index_length DESC
      SQL

      total_size = table_sizes.sum { |t| t['data_mb'].to_f + t['index_mb'].to_f }.round(2)

      # Connection stats
      threads_connected = conn.select_value("SHOW STATUS LIKE 'Threads_connected'")
      # Returns the value column from SHOW STATUS
      active_connections = if threads_connected.is_a?(String)
                             threads_connected.to_i
                           else
                             begin
                               conn.select_value("SELECT VARIABLE_VALUE FROM information_schema.GLOBAL_STATUS WHERE VARIABLE_NAME = 'Threads_connected'").to_i
                             rescue StandardError
                               0
                             end
                           end

      max_connections = begin
        conn.select_value('SELECT @@max_connections').to_i
      rescue StandardError
        0
      end

      # Slow queries from performance_schema (if available)
      slow_queries = begin
        conn.select_all(<<~SQL.squish).to_a
          SELECT LEFT(digest_text, 200) AS query_text,
                 count_star AS exec_count,
                 ROUND(avg_timer_wait / 1000000000, 2) AS avg_ms,
                 ROUND(max_timer_wait / 1000000000, 2) AS max_ms,
                 ROUND(sum_timer_wait / 1000000000, 2) AS total_ms
          FROM performance_schema.events_statements_summary_by_digest
          WHERE schema_name = #{conn.quote(db_name)}
            AND digest_text IS NOT NULL
            AND digest_text NOT LIKE '%performance_schema%'
            AND digest_text NOT LIKE '%information_schema%'
          ORDER BY avg_timer_wait DESC
          LIMIT 20
        SQL
      rescue StandardError => e
        Rails.logger.warn "Metricas::DbAnalyzer: performance_schema not available: #{e.message}"
        []
      end

      {
        db_total_size_mb: total_size,
        db_table_sizes: table_sizes.map do |t|
          {
            'table' => t['table_name'] || t['TABLE_NAME'],
            'rows' => (t['table_rows'] || t['TABLE_ROWS']).to_i,
            'data_mb' => (t['data_mb'] || t['DATA_MB']).to_f,
            'index_mb' => (t['index_mb'] || t['INDEX_MB']).to_f
          }
        end,
        db_active_connections: active_connections,
        db_max_connections: max_connections,
        db_slow_queries: slow_queries.map do |q|
          {
            'query' => q['query_text'] || q['QUERY_TEXT'],
            'count' => (q['exec_count'] || q['EXEC_COUNT']).to_i,
            'avg_ms' => (q['avg_ms'] || q['AVG_MS']).to_f,
            'max_ms' => (q['max_ms'] || q['MAX_MS']).to_f,
            'total_ms' => (q['total_ms'] || q['TOTAL_MS']).to_f
          }
        end
      }
    end
  end
end
