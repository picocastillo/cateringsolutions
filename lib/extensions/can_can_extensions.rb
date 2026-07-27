module CanCan
  class ControllerResource # :nodoc:
    # Hay ciertos formats que los tenemos que autorizar con otras reglas (ej. exportación de datos)
    def authorization_action
      if parent?
        :show
      else
        action = @params[:action].to_sym
        action = :"#{@controller.request.format.symbol}_#{action}" if [:pdf, :xls,
                                                                       :json].include? @controller.request.format.symbol
        action
      end
    end

    # Permite inferir mejor el model si el controller está dentro del mismo module que el model
    def resource_class
      case @options[:class]
      when false  then name.to_sym
      when nil    then compute_type(name.to_s.camelize).constantize
      when String then compute_type(@options[:class]).constantize
      else @options[:class]
      end
    end

    # Sino busca params[:facturacion_item_lista]
    def resource_params_by_namespaced_name
      @params[name] || @params[instance_name]
    end

    private

    def compute_type(type_name)
      /^::/ =~ type_name ? type_name : "#{@controller.class.module_parent.name}::#{type_name}"
    end
  end

  module ControllerResourceBuilder
    # Fix necesario x inherited_resources. Al actualizarlo para Rails 5 resource_arams devuelve un array, no se xq
    def build_resource
      resource = resource_base.new(resource_params.is_a?(Array) ? resource_params.first : (resource_params || {}))
      assign_attributes(resource)
    end
  end
end
