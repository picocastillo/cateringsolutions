module Lazy
  def lazy(methods)
    methods.each do |method_name, default_value|
      class_eval do
        define_method method_name do
          actual_value = super()
          unless actual_value
            actual_value = default_value.respond_to?(:call) ? instance_eval(&default_value) : default_value
            send("#{method_name}=", actual_value)
          end
          actual_value
        end
      end
    end
  end
end
