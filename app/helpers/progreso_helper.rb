module ProgresoHelper
  def eta(progreso)
    if progreso.termino?
      distance_of_time_in_words progreso.fecha_inicio, progreso.fecha_fin, include_seconds: true
    elsif progreso.eta
      distance_of_time_in_words Time.current, progreso.eta
    else
      'Iniciará en instantes'
    end
  end

  def link_to_errores(progreso)
    return if progreso.errores.blank?

    id = dom_id progreso
    dialog = modal id, class: 'modal-errores wider', title: 'Errores' do
      content_tag :ul do
        Array.wrap(progreso.errores).map { |error| content_tag :li, error.html_safe }.join.html_safe
      end
    end
    dialog + link_to_function(content_tag(:i, nil, class: 'ti-alert text-danger'), data: { toggle: 'modal', target: "##{id}" })
  end

  def estado_proceso(proceso)
    text = proceso.ejecutando? ? number_to_percentage(proceso.progreso.pje, precision: 0) : proceso.estado
    content_tag :span, text, class: "label #{label_segun_estado(proceso)}"
  end

  def eta_proceso(proceso)
    if proceso.generando_archivo?
      'Generando archivo...'
    else
      proceso.empezo? || proceso.puesto_actual.to_i < 1 ? eta(proceso.progreso) : "#{proceso.puesto_actual}º en cola de espera"
    end
  end

  def label_segun_estado(proceso)
    case proceso.estado.underscore.to_sym
    when :pendiente then 'label-warning'
    when :ejecutando then 'label-info'
    when :finalizado then 'label-success'
    when :error, :cancelado then 'label-important'
    end
  end
end
