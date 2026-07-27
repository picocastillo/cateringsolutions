module ListasPreciosHelper
  DUPLICATE_COLORS = ['#fff3cd', '#d1ecf1', '#f8d7da', '#d4edda', '#e2d5f1', '#fde2c8', '#cce5ff', '#f5c6cb'].freeze

  def nombre_lista_corto(cliente_ids, clientes_cache, max_length: 40)
    full = nombre_lista_completo(cliente_ids, clientes_cache)
    return full if full.length <= max_length

    truncated = full.truncate(max_length)
    content_tag(:span, truncated, data: { toggle: 'tooltip', placement: 'top' }, title: full)
  end

  def nombre_lista_completo(cliente_ids, clientes_cache)
    if cliente_ids.blank?
      'Lista Base (Todos)'
    else
      nombres = cliente_ids.map { |id| clientes_cache[id]&.nombre || "Cliente ##{id}" }
      "Lista #{nombres.join(', ')}"
    end
  end

  def duplicate_bg_color(precio_id, duplicate_groups)
    group_index = duplicate_groups[precio_id]
    return nil unless group_index

    DUPLICATE_COLORS[group_index % DUPLICATE_COLORS.size]
  end
end
