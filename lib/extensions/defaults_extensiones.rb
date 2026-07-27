module DefaultValueFor
  module ClassMethods
  end

  module InstanceMethods
    def set_default_values
      self.class._all_default_attribute_values.each do |attribute, container|
        next unless new_record? || self.class._all_default_attribute_values_not_allowing_nil.include?(attribute)

        connection_default_value_defined = new_record? && respond_to?("#{attribute}_changed?") && !__send__("#{attribute}_changed?")

        next unless connection_default_value_defined || (attributes[attribute].blank? && attributes["#{attribute}_id"].blank?)

        # allow explicitly setting nil through allow nil option
        if @initialization_attributes.is_a?(Hash) && @initialization_attributes.key?(attribute) &&
           self.class._all_default_attribute_values_not_allowing_nil.exclude?(attribute)
          next
        end

        __send__("#{attribute}=", container.evaluate(self))
        changed_attributes.delete(attribute)
      end
    end
  end
end
