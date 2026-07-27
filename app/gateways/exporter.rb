class Exporter < Infraestructura::Procesos::Proceso
  def perform
    objects = search_scope
    export_started objects
    run objects
    export_finished
    self
  end

  def filepath
    adjunto.path
  end

  private

  def export_started(items)
    count = items.count :all # El :all es x si alguna query tiene un select table.* en cuyo caso un count comun tiraría error
    count = count.size if count.is_a?(Hash) # Si el search_scope tiene un group by el count devuelve un hash
    progreso.start count
  end

  def export_finished
    progreso.finish
    save! unless new_record?
  end

  def query_params
    Hash(params[:q]).merge user: autor
  end
end
