module LinksHelper
  def show_link(object, content = object.to_s)
    link_to_if can?(:show, object), content, object if object
  end

  def edit_link(object, _content = 'Editar', _options = {})
    if can?(
      :update, object
    )
      link_to(content_tag(:i, nil, class: 'ti-marker-alt').html_safe, [:edit, object], class: 'p-r-10',
                                                                                       data: { toggle: 'tooltip', 'original-title' => 'Editar' })
    end
  end

  def destroy_link(object, _content = 'Eliminar', path: object, **options)
    options = options.reverse_merge method: :delete,
                                    data: { confirm: "Está seguro que desea eliminar el registro '#{object}'?", toggle: 'tooltip',
                                            'original-title' => 'Eliminar' }
    link_to(content_tag(:i, nil, class: 'ti-trash').html_safe, path, options) if can?(:destroy, object)
  end

  def create_link(object, content = 'Crear', options = {})
    return unless can?(:create, object)

    object_class = (object.is_a?(Class) ? object : object.class)
    link_to(content, new_polymorphic_path(object_class), options)
  end

  def link_to_cbte_de_mov(c)
    return unless c

    path = if c.is_a?(Cobros::Recibo)
             recibo_path(c)
           else
             (c.is_a?(Entregas::Pago) ? pago_path(c) : comprobante_path(c))
           end
    content_tag :span, link_to(c, path), title: "Total: #{c.total}"
  end

  def solo_hora(t)
    t&.to_s(:short_time)
  end

  def index_link(object, content = 'Ver')
    link_to(content, object.class) if can? :index, object.class
  end

  def button_to_activate(model, html_attrs = {})
    icon = model.discontinued? ? 'habilitar' : 'quitar'
    link_to_activate model, html_attrs.merge(class: "icon #{icon}")
  end

  def link_to_activate model, object_name: model.class.name.demodulize.underscore, route: :polymorphic_path,
                       **html_attrs
    return unless can?(:destroy, model)

    icon = model.discontinued? ? 'ti-check' : 'ti-na'
    title = model.discontinued? ? 'Activar' : 'Desactivar'
    data = { toggle: 'tooltip', 'original-title' => title }
    path_opts = { "#{object_name}[active]" => model.discontinued?.to_s }
    link_to content_tag(:i, nil, class: icon).html_safe, send(route, model, path_opts),
            html_attrs.merge(method: :put, remote: true, data: data)
  end

  def link_to_activate_with_comments(model)
    return unless can?(:destroy, model)

    text = model.discontinued? ? 'Activar' : 'Desactivar'
    link_to_function text, class: 'toggle-status-with-comment',
                           data: { url: polymorphic_path(model), active: model.discontinued? }
  end

  # El helper de mismo nombre no existe mas en rails 4. Nosotros mayormente lo usabamos por el
  # javascript:void(0) para no tener q acordarse de hacer return false en el onclick.
  def link_to_function(name, **options)
    content_tag :a, name, options.reverse_merge(href: 'javascript:void(0)')
  end

  def import_link(class_to_auth, text: 'Importar')
    link_to_function text, data: { toggle: 'modal', target: '#importar' } if can?(:import, class_to_auth)
  end

  def export_link class_to_auth, path: polymorphic_path(class_to_auth, filtered_params.merge(format: :xls)),
                  text: 'Exportar', **html_options
    return unless can?(:xls_index, class_to_auth)

    link_to text, path,
            html_options.reverse_merge(class: 'export-link', data: { confirm: 'Se exportarán todos los registros mostrados en pantalla. Desea continuar?' })
  end

  def edit_pedido_link(t, text = nil, con_mensaje = true, html_options = {})
    return unless can?(:re_edit, t)

    texto = text || content_tag(:i, nil, class: 'ti-marker-alt').html_safe
    tooltips = text ? {} : { 'toggle' => 'tooltip', 'original-title' => 'Editar' }
    if current_user.pedido_pendiente
      if con_mensaje && current_user.pedido_pendiente != t
        confirm_msg = 'Ya tiene un pedido en el Carrito. Desea eliminar el mismo y ' \
                      "continuar con la edición del Pedido #{t}?"
        link_to(texto, re_edit_pedido_path(t), html_options.merge(method: :post,
                                                                  data: { confirm: confirm_msg }.merge(tooltips)))
      else
        link_to(texto, edit_pedido_path(t), html_options.merge(data: {}.merge(tooltips)))
      end
    else
      pedido_str = t.pendiente? ? '' : t.to_s
      confirm_msg = "Desea editar el pedido #{pedido_str}? Recuerde que deberá finalizarlo " \
                    'nuevamente para que sea Aceptado o de lo contrario el mismo se eliminará.'
      link_to(texto, re_edit_pedido_path(t), html_options.merge(method: :post,
                                                                data: { confirm: confirm_msg }.merge(tooltips)))
    end
  end

  def edit_pedido_mostrador_link(t, text = nil)
    return unless can?(:re_edit, t)

    texto = text || content_tag(:i, nil, class: 'ti-marker-alt').html_safe
    tooltips = text ? {} : { 'toggle' => 'tooltip', 'original-title' => 'Editar' }
    if current_user.pedido_pendiente&.facturado?
      if current_user.pedido_pendiente == t
        link_to(texto, edit_ventas_mostrador_pedido_path(t), data: {}.merge(tooltips))
      else
        confirm_msg = 'Ya tiene un pedido en el Carrito. Desea eliminar el mismo y continuar ' \
                      "con la edición del Pedido #{t}? Recuerde que deberá Confirmar " \
                      'nuevamente este pedido o de lo contrario el mismo se eliminará.'
        link_to(texto, edit_ventas_mostrador_pedido_path(t), method: :post,
                                                             data: { confirm: confirm_msg }.merge(tooltips))
      end
    else
      pedido_str = t.pendiente? ? '' : t.to_s
      confirm_msg = "Desea editar el pedido #{pedido_str}? Recuerde que deberá Confirmar " \
                    'nuevamente este pedido o de lo contrario el mismo se eliminará.'
      link_to(texto, edit_ventas_mostrador_pedido_path(t), method: :post,
                                                           data: { confirm: confirm_msg }.merge(tooltips))
    end
  end

  def export_link_cocina fecha, venta_mostrador: nil, **html_options
    q_params = { fecha: fecha }
    q_params[:venta_mostrador] = venta_mostrador.to_s unless venta_mostrador.nil?
    path = inicio_index_path(filtered_params.merge(format: :xls, q: q_params))
    return unless can?(:xls_index, :inicio)

    link_to 'XLS', path,
            html_options.reverse_merge(
              data: { confirm: 'Se exportará a XLS el Reporte del día que se está visualizando en pantalla. Desea continuar?' }
            )
  end

  def link_to_etiquetas(path)
    link_to 'Exportar PDF', path, class: 'export-pdf', target: '_blank', rel: 'noopener'
  end

  def link_to_pdf(path)
    link_to 'PDF', path, class: 'export-pdf'
  end

  def export_link_despacho path: etiquetas_path(filtered_params.merge(format: :xls)), **html_options
    return unless can?(:xls_index, :despachos)

    link_to 'Exportar XLS', path,
            html_options.reverse_merge(
              class: 'export-link',
              data: { confirm: 'Se exportará a XLS el Reporte de Despacho que se está visualizando en pantalla. Desea continuar?' }
            )
  end

  def export_link_precios path: listas_precios_path(filtered_params.merge(format: :xls)), **html_options
    return unless can?(:index, Productos::Precio)

    link_to 'Exportar', path,
            html_options.reverse_merge(
              class: 'export-link',
              data: {
                confirm: 'Se exportará a XLS el Reporte de Precios de los Productos ' \
                         'que se están visualizando en pantalla. Desea continuar?'
              }
            )
  end

  def icon_link(icon_class, path, options = {})
    options[:class] ||= 'btn btn-small'
    link_to content_tag('i', '', class: "icon-#{icon_class}"), path, options
  end

  def icon_to_function(icon_class, **options)
    options[:class] ||= 'btn btn-narrow'
    link_to_function content_tag('i', '', class: "icon-#{icon_class}"), **options
  end

  def fileupload_link text: 'Importar', title: nil, **options
    content_tag :span, class: ['btn', 'fileinput-button', options[:class]], data: { tooltip: title } do
      content_tag(:span, text) + content_tag(:input, '', type: 'file', name: 'adjunto', id: 'adjunto')
    end
  end

  def volver_link
    link_to_function 'Volver', onclick: 'history.go(-1)', class: 'btn btn-default'
  end

  def print_link(object, options = {})
    options[:class] = "silentprint #{options[:class]}".strip
    link_if can?(:export_show, object), 'Imprimir', polymorphic_path(object, format: :pdf), options
  end

  def link_to_favorito(favorito, path)
    link_to icono_favorito(favorito), path, method: :put, remote: true
  end

  def icono_favorito(favorito, opts = {})
    content_tag 'i', nil, opts.reverse_merge(
      class: "fa fa-star#{'-o' unless favorito} favorito",
      title: favorito ? 'Quitar de Favoritos' : 'Agregar a Favoritos'
    )
  end

  def etiqueta_activo(e)
    # Handle both 'activo' (Stock) and 'active' (Categoria with acts_as_discontinued)
    value = e.respond_to?(:activo) ? e.activo : e.active
    is_active = e.respond_to?(:activo?) ? e.activo? : e.active?
    content_tag :span, value.to_sino, class: "label label-#{is_active ? 'success' : 'danger'}"
  end
end
