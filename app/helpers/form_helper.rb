module FormHelper
  def label_for(model, field_to_show = :to_s)
    content_tag :label, for: dom_id(model) do
      model.send(field_to_show)
    end
  end

  # El link_to_if muestra el texto del link si la condición no se cumple. Este no lo muestra directamente.
  def link_if(condition, name, options = {}, html_options = {}, &)
    link_unless(!condition, name, options, html_options, &)
  end

  def link_unless(condition, name, options = {}, html_options = {}, &block)
    if condition
      if block_given?
        block.arity <= 1 ? yield(name) : yield(name, options, html_options)
      end
    else
      link_to(name, options, html_options)
    end
  end

  def table(list, groups = 3)
    content_tag :table, border: 0, cellspacing: 0, class: 'table-values' do
      list.in_groups_of(groups).map do |row|
        content_tag :tr do
          row.map do |cell|
            content_tag :td, cell, class: 'cell'
          end.join.html_safe
        end
      end.join.html_safe
    end
  end

  def clear_fields
    button_tag 'Limpiar', class: 'btn clear-form', type: 'button'
  end

  def search_buttons(f, options = {})
    html_options = { type: options[:subform] ? 'button' : 'submit', class: 'btn btn-primary search-btn' }
    # Only add target: '_blank' if form is not remote
    html_options[:target] = '_blank' unless f.options[:remote]
    content_tag :div, f.submit(options[:title].presence || 'Buscar', html_options) + clear_fields, class: 'form-actions'
  end

  def inline_form_for(object, *, **options, &)
    options[:builder] = SimpleForm::FormBuilder
    options[:html] ||= {}
    ((options[:html][:class] ||= '') << ' form-inline').strip!
    form_for(object, *, **options, &)
  end

  def query_form_for(query, *, **options, &)
    options[:as] ||= :q
    options[:method] ||= :get
    options[:url] ||= send query.class.name.demodulize.underscore.sub '_query', '_path'
    options[:html] ||= {}
    ((options[:html][:class] ||= '') << ' subform').strip! if options[:remote]
    inline_form_for(query, *, **options, &)
  end

  def views_buttons(f, q, views, field: :vista)
    content_tag :div, class: 'form-actions vistas-container' do
      content_tag :div, class: 'btn-group vistas', data: { toggle: 'buttons-radio' } do
        views.map do |(view, opts)|
          active_class = 'active' if q.send(field) == view.to_s
          tooltip_position = (opts[:position] || {}).reverse_merge my: 'bottom center', at: 'top center'
          content_tag :a,
                      href: '#', class: "btn #{active_class} btn-#{field}-#{view}", tabindex: -1,
                      data: { vista: view, tooltip: { content: opts[:title], delay: 1000, position: tooltip_position } } do
            if opts[:icon]
              content_tag :i, nil, class: "icon-#{opts[:icon]}"
            else
              opts[:text]
            end
          end
        end.join.html_safe + f.hidden_field(field)
      end
    end
  end
end
