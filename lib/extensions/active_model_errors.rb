# Cumple dos funciones:
# Si un attribute message comienza con ^, se omite el attribute (como si se hubiese agregado al base digamos)
# Permite mostrar los nested errores de forma mas amigable. Por defecto, cuando
# config.active_record.index_nested_attribute_errors = true, Rails devuelve por ej. items[0].detalle en los errors,
# y en el full_message sale "Items[0] detalle no puede estar en blanco". Con este parche muestra
# "1º Item: Detalle no puede...". También permite en un model definir un prefix_for_association_in_errors
# y así podemos traducir Lentes[0] a OD por ej.
module KIOSK
  module Errors
    def full_message(attribute, message)
      if attribute.to_s.include? '.'
        *association_path, attribute = attribute.to_s.split('.')

        associations_prefix = association_path.map.with_index do |association, i|
          # El gsub es necesario porque sino no funca en CollectionProxy
          owner = i.zero? ? @base : @base.instance_eval(association_path[0..(i - 1)].join('.').gsub('[', '.to_a['))
          owner_class = owner.class
          if owner.respond_to?(:prefix_for_association_in_errors, true) &&
             (prefix = owner.send(:prefix_for_association_in_errors, association)).present?
            "#{prefix}:"
          elsif association =~ /(\w+)\[(\d+)\]/
            association = ::Regexp.last_match(1)
            index = ::Regexp.last_match(2).to_i
            translated_association = owner_class.human_attribute_name(association,
                                                                      default: association.humanize).singularize
            "#{index + 1}º #{translated_association}:"
          else
            translated_association = owner_class.human_attribute_name(association, default: association.humanize)
            "#{translated_association}:"
          end
        end.join(' ')

        # Sin esto al hacer puntos_venta[0] no funcionaba ya que la asociation no es un array
        # sino un proxy de AR con lo cual evaluaba el metodo PuntoVenta.[], como si fuera un scope
        corrected_path = association_path.join('.').gsub(/\[(\d+)\]/, '.to_a[\1]')
        if attribute != 'base' && !message.start_with?('^')
          translated_attribute = @base.instance_eval(corrected_path).class.human_attribute_name(attribute,
                                                                                                default: attribute.humanize)
        end
        attr_name = [associations_prefix, translated_attribute].compact.join(' ')

        attribute = :base
        message = "#{attr_name} #{message.sub('^', '')}"
      elsif /^\^/.match?(message)
        attribute = :base
        message = message[1..]
      end

      super
    end
  end
end

ActiveModel::Errors.prepend KIOSK::Errors

# workaround for rails bug with association indices.
# see https://github.com/rails/rails/pull/24728
module ActiveRecord
  module AutosaveAssociation
    # Returns the record for an association collection that should be validated
    # or saved. If +autosave+ is +false+ only new records will be returned,
    # unless the parent is/was a new record itself.
    def associated_records_to_validate_or_save(association, new_record, autosave)
      if new_record || autosave
        association&.target
      else
        association.target.select(&:new_record?)
      end
    end
  end
end
