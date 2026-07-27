module Productos
  class StocksQuery < ApplicationQuery
    attr_accessor :producto_nombre, :categoria_ids, :status_stock_ids,
                  :stock_bajo, :stock_critico, :sin_stock, :local_ids,
                  :user, :busqueda, :solo_categorias_stock_activo

    def relation
      q = Stock.includes(:producto, :tienda, :local, producto: :categoria)
               .joins(:producto)
               .order('productos.nombre ASC')

      # Filter by user's active tienda
      q = q.where(tienda_id: user.tienda_activa) if user&.tienda_activa

      # Filter by product name
      q = q.where('productos.nombre LIKE ?', "%#{producto_nombre}%") if producto_nombre.present?

      # Filter by category
      q = q.where(productos: { categoria_id: categoria_ids }) if categoria_ids.present?

      # Filter by categories with stock_activo (enabled by default)
      # Only filter out if explicitly set to false or '0'
      unless ['0', false].include?(solo_categorias_stock_activo)
        q = q.joins('INNER JOIN categorias ON productos.categoria_id = categorias.id')
             .where(categorias: { stock_activo: true })
      end

      # Filter by local
      if local_ids.present?
        if local_ids.include?('null') || local_ids.include?(nil)
          # Include both specified locals and null (main stock)
          local_conditions = local_ids.reject { |id| id == 'null' || id.nil? }
          q = if local_conditions.any?
                q.where('productos_stocks.local_id IN (?) OR productos_stocks.local_id IS NULL', local_conditions)
              else
                q.where(productos_stocks: { local_id: nil })
              end
        else
          q = q.where(local_id: local_ids)
        end
      end

      # Filter by stock status (multi-select with OR logic)
      if status_stocks.present? && status_stocks.is_a?(Array)
        status_conditions = []

        status_stocks.each do |status|
          case status
          when 'con_stock'
            status_conditions << 'cantidad_actual > 0'
          when 'sin_stock'
            status_conditions << 'cantidad_actual = 0'
          when 'stock_bajo'
            status_conditions << '(cantidad_actual <= cantidad_minima AND cantidad_actual > 0)'
          when 'stock_critico'
            status_conditions << '(cantidad_actual = 0 OR (cantidad_actual < cantidad_minima AND cantidad_actual <= 1))'
          end
        end

        q = q.where(status_conditions.join(' OR ')) if status_conditions.any?
      elsif status_stocks.present?
        # Single select fallback
        status_stocks.each do |status|
          case status
          when 'con_stock'
            q = q.con_stock
          when 'sin_stock'
            q = q.sin_stock
          when 'stock_bajo'
            q = q.stock_bajo
          when 'stock_critico'
            q = q.stock_critico
          end
        end
      end

      # Individual stock status filters (can be combined with AND - kept for backward compatibility)
      q = q.stock_bajo if ['1', true].include?(stock_bajo)
      q = q.stock_critico if ['1', true].include?(stock_critico)
      q = q.sin_stock if ['1', true].include?(sin_stock)

      # General search across product data
      if busqueda.present?
        search_terms = busqueda.to_s.split.compact_blank
        if search_terms.present?
          conditions = []
          params = {}

          search_terms.each_with_index do |term, idx|
            key = :"term_#{idx}"
            conditions << "(productos.nombre LIKE :#{key} OR productos.codigo LIKE :#{key} " \
                          "OR productos.codigos_externos LIKE :#{key})"
            params[key] = "%#{term}%"
          end

          q = q.where(conditions.join(' AND '), params)
        end
      end

      # Only active products
      q = q.where(productos: { discontinued_at: nil })

      # Only active stocks
      q.where(activo: true)
    end

    def total_productos
      relation.select('DISTINCT productos_stocks.producto_id').count
    end

    def resumen_stocks
      # Use a single SQL query with conditional counts instead of 5 separate queries
      tbl = 'productos_stocks'
      bajo_cond = "#{tbl}.cantidad_actual <= #{tbl}.cantidad_minima AND #{tbl}.cantidad_actual > 0"
      critico_cond = "#{tbl}.cantidad_actual = 0 OR " \
                     "(#{tbl}.cantidad_actual < #{tbl}.cantidad_minima AND #{tbl}.cantidad_actual <= 1)"

      result = ActiveRecord::Base.connection.select_one(
        relation.select(
          'COUNT(*) as total',
          "SUM(CASE WHEN #{tbl}.cantidad_actual > 0 THEN 1 ELSE 0 END) as con_stock_count",
          "SUM(CASE WHEN #{tbl}.cantidad_actual = 0 THEN 1 ELSE 0 END) as sin_stock_count",
          "SUM(CASE WHEN #{bajo_cond} THEN 1 ELSE 0 END) as stock_bajo_count",
          "SUM(CASE WHEN #{critico_cond} THEN 1 ELSE 0 END) as stock_critico_count"
        ).reorder(nil).to_sql
      )

      {
        total: result['total'].to_i,
        con_stock: result['con_stock_count'].to_i,
        sin_stock: result['sin_stock_count'].to_i,
        stock_bajo: result['stock_bajo_count'].to_i,
        stock_critico: result['stock_critico_count'].to_i
      }
    end

    def status_stocks
      return [] if status_stock_ids.blank?

      if status_stock_ids.is_a?(Array)
        status_stock_ids.compact_blank
      else
        status_stock_ids.to_s.split(',').compact_blank
      end
    end
  end
end
