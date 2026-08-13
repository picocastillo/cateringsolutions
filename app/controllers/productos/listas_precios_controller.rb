module Productos
  class ListasPreciosController < ApplicationController
    def index
      authorize! :index, Productos::Precio
      respond_to do |format|
        format.any :html, :js do
          @query = ListasPreciosQuery.new(query_params)
          if @query.productos_sin_precio?
            @productos_sin_precio = @query.productos_sin_precio_query.paginate(page: params[:page], per_page: 50)
          else
            @precios = @query.page(params[:page]).per_page(50)
            @duplicate_groups = @query.duplicate_groups
          end
        end
        format.xls { export_in_background Productos::PreciosExporter }
      end
    end

    def destroy
      authorize! :index, Productos::Precio
      precio = Productos::Precio.joins(:producto)
                                .where(productos: { tienda_id: current_user.tienda_activa.id })
                                .find(params[:id])
      precio.destroy!
      flash[:notice] = 'Precio eliminado correctamente.'
      redirect_to listas_precios_path
    end

    def import
      authorize! :index, Productos::Precio
      return unless Tiendas::HostResolver.matches?(request.host, tienda_activa.dominio) || !Rails.env.production?

      import_in_background Productos::PreciosImporter
    end

    def eliminar_duplicados
      authorize! :index, Productos::Precio
      query = ListasPreciosQuery.new(query_params)

      # IMPORTANT: do NOT reuse the query relation directly here.
      # `base_scope` joins `clientes_precios` and applies `.group('precios.id')`,
      # which interacts badly with `.includes(:clientes)` in MySQL — the
      # association preload can come back with the WRONG (often empty)
      # collection, causing universal precios and client-specific precios
      # with the same producto/importe/fechas to collapse into one group and
      # the client-specific one to get deleted.
      #
      # Instead: pluck the candidate IDs from the filtered query, then reload
      # the precios via a clean scope (no group/join) so `.includes(:clientes)`
      # eager-loads the join table correctly.
      candidate_ids = query.reorder('').pluck(Arel.sql('precios.id'))
      precios = Productos::Precio
                .where(id: candidate_ids, discontinued_at: nil)
                .joins(:producto)
                .where(productos: { tienda_id: current_user.tienda_activa.id })
                .includes(:clientes)
                .to_a

      groups = precios.group_by do |p|
        [p.producto_id, p.importe.to_d, p.clientes.map(&:id).sort, p.fecha_desde, p.fecha_hasta]
      end

      ids_to_delete = []
      groups.each_value do |duplicates|
        next unless duplicates.size > 1

        # Keep the most recently updated (and highest id as tiebreaker) — delete the rest.
        sorted = duplicates.sort_by { |p| [p.updated_at || p.created_at || Time.zone.at(0), p.id] }
        ids_to_delete.concat(sorted[0..-2].map(&:id))
      end

      if ids_to_delete.any?
        # Use destroy_all (not delete_all) so HABTM `clientes_precios` join
        # rows are cleaned up; otherwise orphan join rows remain forever.
        Productos::Precio.where(id: ids_to_delete).destroy_all
        flash[:notice] = "Se eliminaron #{ids_to_delete.size} precios duplicados."
      else
        flash[:notice] = 'No se encontraron precios duplicados con mismo importe para eliminar.'
      end

      redirect_to listas_precios_path
    end
  end
end
