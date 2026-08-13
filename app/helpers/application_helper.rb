module ApplicationHelper
  def color_cocina(total, listos, cocinados)
    if listos.to_i.positive?
      '#dc3545'
    elsif total.to_i.positive? && cocinados.to_i.positive? && listos.to_i.zero? && total.to_i == cocinados.to_i
      '#28a745'
    elsif total.to_i != cocinados.to_i && (total.to_i.positive? || cocinados.to_i.positive?)
      '#ffb22b'
    end
  end

  def page(**options)
    content_for(:page_id) { options[:id] } if options[:id].present?
    content_for(:title) { options[:title].to_s } if options[:title].present?
    content_for(:raiz) { options[:raiz].html_safe } if options[:raiz].present?
    content_for(:hojas) { options[:hojas].html_safe } if options[:hojas].present?
    content_for(:oculto) { options[:oculto] } if options[:oculto].present?
    if options[:acciones].present?
      acs = options[:acciones].map do |a|
        content_tag(:div, a.html_safe, class: 'd-flex m-l-10 hidden-sm-down')
      end
      content_for(:actions) do
        content_tag(:div,
                    content_tag(:div, acs.join.html_safe,
                                class: 'd-flex m-t-10 justify-content-end acciones-buttons'),
                    class: 'col-lg-7 col-4 align-self-center')
      end
    end
    content_for(:acciones) { options[:acciones].join.html_safe } if options[:acciones].present?
  end

  def import_dialog(title, path)
    modal 'importar', title: title do
      form_for :proceso, url: path, html: { multipart: true, class: 'import-form' } do |f|
        header = block_given? ? capture { yield f } : ''.html_safe
        header + f.file_field(:adjunto) + f.submit('Importar', class: 'btn btn-primary')
      end
    end
  end

  def import_dialog_with_warning(title, path)
    modal 'importar', title: title do
      form_for :proceso, url: path, html: { multipart: true, class: 'import-form' } do |f|
        header = block_given? ? capture { yield f } : ''.html_safe
        header + f.file_field(:adjunto) + f.submit(
          'Importar', class: 'btn btn-primary',
                      data: { confirm: 'Se importarán los pedidos del documento ' \
                                       'y no habrá marcha atrás. Desea continuar?' }
        )
      end
    end
  end

  def page_id
    id = content_for(:page_id) || begin
      action = ['new', 'create', 'edit', 'update'].include?(action_name) ? 'form' : action_name
      [controller_name, action].join('-').tr '_', '-'
    end
    "page-#{id}"
  end

  def turbolinks_cache_control_meta_tag
    tag.meta(name: 'turbolinks-cache-control', content: @turbolinks_cache_control || 'cache')
  end

  def modo_prueba?
    ENV['MODO_PRUEBA'] == 'true'
  end

  def loading_indicator
    content_tag :div, '', class: 'busy loading-indicator'
  end

  def discontinuado(model, str = model.to_s)
    model.discontinued? ? content_tag(:span, str, class: 'discontinuado') : str
  end

  def icono_tip(*args, &)
    qtip_opts = args.extract_options!
    i_class = qtip_opts.delete(:class) || 'icono-info-tip'
    content = args.first || capture(&)
    content_tag :i, nil, class: "fa fa-info-circle #{i_class}", data: { toggle: 'tooltip', 'original-title' => content }
  end

  def paginador(objects, options = {})
    %(
      <div class="col-md-12" style="text-align: center">
        <div class="kiosk_pagination#{' ajax' if options.delete(:ajax)}">
          #{will_paginate(objects, container: false, previous_label: 'Anterior', next_label: 'Siguiente')}
          <div class="page_info">
            #{page_entries_info objects}
          </div>
        </div>
      </div>
    ).html_safe
  end

  def page_entries_info(collection)
    format(%(Viendo <b>%d&nbsp;-%d</b> de <b>%d</b> totales), collection.offset + 1,
           collection.offset + collection.length, collection.total_entries)
  end

  def refresh(every, update: nil, url: nil)
    concat content_tag(:div, '', id: 'auto-refresh', data: { every: every, update: update, url: url })
  end

  def refresh_inicio(every)
    concat content_tag(:div, '', id: 'auto-refresh-inicio', data: { every: every })
  end

  def modal(id, options = {}, &)
    classes = ['modal', 'none-border']
    classes << 'fade' unless Rails.env.test?
    classes << 'modal-remote' unless block_given?
    classes << options[:class] if options[:class]
    %(
      <div class="#{classes.join(' ')}" id="#{id}" style="display:none" tabindex="-1">
        <div class="modal-dialog">
          <div class="modal-content">
            <div class="modal-header">
              <h3>#{options[:title]}</h3>
              <button type="button" class="close" data-dismiss="modal" title="Cerrar">×</button>
              </div>
              <div class="col-md-12 modal-body" style="padding: 30px">
              #{block_given? ? capture(&) : 'Cargando...'}
            </div>
          </div>
        </div>
      </div>
    ).html_safe
  end

  def loader(message = nil)
    render partial: 'shared/loader', locals: { message: message }
  end

  def loader_script(path)
    javascript_tag "$(function() { $.get('#{path}'); });"
  end

  # Daily Menu Card Helper - Creates beautiful cards for school meal ordering
  # Now splits each variant into its own individual card
  def daily_menu_card(menu_diario, precios, pedido, _options_count = 1)
    return '' if precios.empty?

    # Calculate column classes based on options count - now need to account for more cards
    total_variants = precios.count
    col_classes = case total_variants
                  when 1..3
                    'col-12 col-sm-6 col-md-6 col-lg-4 col-xl-4'
                  when 4..6
                    'col-12 col-sm-6 col-md-4 col-lg-3 col-xl-3'
                  else
                    'col-12 col-sm-6 col-md-4 col-lg-3 col-xl-2'
                  end

    # Generate one card per variant (precio)
    precios.map do |precio|
      content_tag :div, class: "#{col_classes} producto-venta mb-4", style: 'min-height: initial;max-width: 330px' do
        card_class = ['menu-card', 'mini-form']
        card_class << 'menu-card--no-image' unless precio.producto.imagenes.first

        content_tag :div, class: card_class.join(' ') do
          daily_menu_header(precio, menu_diario) + daily_menu_single_variant(precio, pedido, menu_diario)
        end
      end
    end.join.html_safe
  end

  private

  def daily_menu_header(precio, menu_diario)
    content_tag :div, class: 'menu-header', style: menu_header_style(precio.producto.color_safe) do
      daily_menu_category_badge(precio.producto) +
        daily_menu_food_image(precio.producto) +
        daily_menu_title(menu_diario.descripcion)
    end
  end

  # Menu type icon mapping - Returns appropriate icon class for different menu types
  def menu_type_icon(menu_name)
    case menu_name&.downcase
    when /rico/
      'mdi mdi-fire'        # Fire icon for calories/energy
    when /saludable/, /healthy/
      'mdi mdi-heart-pulse' # Heart pulse for healthy menus
    when /veggie/, /vegetarian/, /vegetal/
      'mdi mdi-sprout'        # Sprout icon for veggie menus
    when /student/, /estudiant/
      'mdi mdi-school'
    when /suggestion/, /sugerencia/
      'mdi mdi-lightbulb'
    when /mini/
      'mdi mdi-food-variant'  # Food variant for mini portions
    else
      'mdi mdi-silverware-fork-knife' # Default cutlery icon
    end
  end

  # Enhanced daily menu category badge with icons
  def daily_menu_category_badge(producto)
    icon_class = menu_type_icon(producto.nombre)

    content_tag :div, class: 'category-badge' do
      content_tag(:i, '', class: "#{icon_class} menu-icon", style: 'margin-right: 8px;') +
        content_tag(:span, producto.to_s, class: 'menu-name')
    end
  end

  def daily_menu_food_image(producto)
    return ''.html_safe unless producto.imagenes.first

    content_tag :div, class: 'food-image' do
      image_tag producto.imagenes.first.url(:thumb),
                style: 'width: 100%; height: 100%; object-fit: cover;'
    end
  end

  def daily_menu_title(descripcion)
    content_tag :h4, descripcion
  end

  def daily_menu_variants(precios, pedido, menu_diario)
    content_tag :div, class: 'menu-variants' do
      precios.map do |precio|
        if ['Menú Calórico', 'Menú Saludable', 'Menú Veggie'].include? precio.producto.nombre
          content_tag(:span, daily_menu_main_variant(precio, pedido, menu_diario).html_safe, class: 'mini-form')
        else
          content_tag(:span, daily_menu_mini_variant(precio, pedido, menu_diario).html_safe, class: 'mini-form')
        end
      end.join.html_safe
    end
  end

  def daily_menu_main_variant(precio, pedido, menu_diario)
    precio_money = Danconia::Money.new(precio.importe)
    cantidad = pedido.productos_solicitados.find { |x| x.producto == precio.producto }.try(&:cantidad).to_i

    content_tag :div, class: 'variant-item' do
      daily_menu_variant_header('Porción Completa', precio.producto.descripcion, precio_money, 'full') +
        daily_menu_quantity_controls(precio.producto, cantidad, precio_money) +
        hidden_field_tag('productoid', precio.producto.id) +
        hidden_field_tag('menudiarioid', menu_diario.id)
    end
  end

  def daily_menu_mini_variant(precio, pedido, menu_diario)
    precio_money = Danconia::Money.new(precio.importe)
    cantidad = pedido.productos_solicitados.find { |x| x.producto == precio.producto }.try(&:cantidad).to_i

    content_tag :div, class: 'variant-item' do
      daily_menu_variant_header('Porción Mini', precio.producto.descripcion, precio_money, 'mini') +
        daily_menu_quantity_controls(precio.producto, cantidad, precio_money) +
        hidden_field_tag('productoid', precio.producto.id) +
        hidden_field_tag('menudiarioid', menu_diario.id)
    end
  end

  def daily_menu_single_variant(precio, pedido, menu_diario)
    precio_money = Danconia::Money.new(precio.importe)
    cantidad = pedido.productos_solicitados.find { |x| x.producto == precio.producto }.try(&:cantidad).to_i

    if tienda_activa.id == 1
      if ['450', '500', '550'].any? { |n| precio.producto.nombre.include? n }
        portion_type = 'Porción Full'
        variant_type = 'full'
      else
        portion_type = 'Porción Mini'
        variant_type = 'mini'
      end
    elsif ['mini'].any? { |n| precio.producto.nombre.downcase.include? n }
      portion_type = 'Porción Mini'
      variant_type = 'mini'
    else
      portion_type = 'Porción Full'
      variant_type = 'full'
    end
    css_class = 'variant-item'

    content_tag :div, class: css_class do
      daily_menu_variant_header(portion_type, precio.producto.descripcion, precio_money, variant_type) +
        daily_menu_quantity_controls(precio.producto, cantidad, precio_money) +
        hidden_field_tag('productoid', precio.producto.id) +
        hidden_field_tag('menudiarioid', menu_diario.id)
    end
  end

  def daily_menu_variant_header(portion_type, _descripcion, precio, variant_type)
    content_tag :div, class: 'variant-header', style: 'white-space: nowrap' do
      content_tag(:div, class: 'variant-info') do
        content_tag(:span, portion_type, class: "variant-badge #{variant_type}-portion")
      end +
        content_tag(:div, class: 'variant-price') do
          precio_text = precio.nil? || precio.to_f.zero? ? 'Sin Precio' : precio.to_s
          content_tag :div, precio_text, class: "price-badge #{variant_type}-price"
        end
    end
  end

  def daily_menu_quantity_controls(producto, cantidad, precio)
    content_tag :div, class: 'quantity-controls' do
      # Minus button
      minus_button = content_tag(:span, link_to('#',
                                                class: 'quantity-btn minus cambiadores-cantidad menos',
                                                data: { suma: '-1' }) do
        content_tag :i, '', class: 'fa fa-minus'
      end)

      # Quantity input
      quantity_input = text_field_tag :cantidad, cantidad,
                                      class: "cantidad #{'mayorcero' if cantidad.positive?}",
                                      id: "input_cantidad_#{producto.id}",
                                      readonly: true,
                                      data: {
                                        productoid: producto.id,
                                        precio: precio.to_f,
                                        nombre: producto.to_s.truncate(32),
                                        imagen: producto.imagen_principal
                                      }

      # Plus button
      plus_button = content_tag(:span,
                                link_to('#',
                                        class: 'quantity-btn plus cambiadores-cantidad mas',
                                        data: { suma: '1' }) do
                                  content_tag :i, '', class: 'fa fa-plus'
                                end)

      minus_button + quantity_input + plus_button
    end
  end

  def menu_header_style(color)
    "background: linear-gradient(135deg, #{color} 0%, #{color}dd 100%);"
  end
end
