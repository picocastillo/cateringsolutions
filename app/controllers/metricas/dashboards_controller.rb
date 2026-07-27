module Metricas
  class DashboardsController < ApplicationController
    def index
      authorize! :index, :metricas

      @tiendas = Tiendas::Tienda.order(:nombre).pluck(:id, :nombre)
      @tienda_id = params[:tienda_id].presence&.to_i

      base = Metricas::Snapshot.ultimos_dias(30)
      base = @tienda_id ? base.para_tienda(@tienda_id) : base.globales
      @snapshots = base.to_a
      @latest = @snapshots.select { |s| s.fecha < Time.zone.today }.last || @snapshots.last
      @errors = Metricas::ErrorEntry.recientes(20).to_a
    end
  end
end
