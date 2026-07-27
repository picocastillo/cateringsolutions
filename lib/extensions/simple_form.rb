module SimpleForm
  class FormBuilder
    def default_button(label = nil)
      template.content_tag :div do
        button label, class: 'btn btn-success waves-effect waves-light m-r-10', data: { disable_with: 'Procesando...' }
      end
    end

    def default_button_vm
      template.content_tag :div do
        button 'Confirmar e Imprimir (F10)', class: 'btn btn-success waves-effect waves-light m-r-10',
                                             id: 'boton-confirmar-pedido-vm',
                                             data: { disable_with: 'Procesando...',
                                                     confirm: 'Confirmará e imprimirá el pedido! Está seguro?' }
      end
    end

    def default_and_reset_button(label = nil, options = {})
      template.content_tag :div, class: 'col-sm-12' do
        button(label, class: 'btn btn-success waves-effect waves-light m-r-10',
                      data: { disable_with: 'Procesando...' }) + reset_saved_form_button(options)
      end
    end

    def reset_saved_form_button(_options)
      html_options = { class: 'btn btn-inverse waves-effect waves-light',
                       title: 'Resetea el formulario a su estado inicial.' }
      path = if object.errors.empty?
               '#'
             elsif object.new_record?
               template.new_polymorphic_path object
             else
               template.edit_polymorphic_path object
             end
      template.link_to 'Reiniciar', path, html_options
    end

    remove_method :button # El de SimpleForm recibe como arg un symbol supongo que xq luego se usa i18n, y no acepta un string que es lo que usamos siempre
  end
end
