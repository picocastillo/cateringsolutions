module ActiveRecord
  module NestedAttributesRejectMarked
    def accepts_nested_attributes_for(*attr_names)
      super
      nested_attributes_options.each do |attr_name, options|
        next unless options[:allow_destroy]

        class_eval <<-EORUBY, __FILE__, __LINE__ + 1
            def #{attr_name}!
              #{attr_name}.reject &:marked_for_destruction?
            end
        EORUBY
      end
    end
  end
end

ActiveSupport.on_load(:active_record) { extend ActiveRecord::NestedAttributesRejectMarked }
