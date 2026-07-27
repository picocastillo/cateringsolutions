module Defaults
  def defaults(attrs_and_default_values)
    class_eval do
      after_initialize do
        if new_record?
          attrs_and_default_values.each do |attribute, default|
            if send(attribute).nil? && read_attribute_before_type_cast(attribute).nil?
              default = instance_exec(&default) if default.respond_to? :call
              send :"#{attribute}=", default
            end
          end
        end
      end
    end
  end
end
