# Esto se usa en el polymorphic_path. Por convension cuando hacés link_to 'detalles', @modelo, se llama al polymorphic_path
# que devuelve inventario_modelo_path (con el module), pero en las routes normalmente usamos scopes (es decir, sin el module) para acortar las rutas.
# El patch sobre el _singularize cambia eso.
# El patch del model_name permite pisar las route_key en ciertas clases, ej. en Contabilidad::Cuenta quiero usar cuentas_cbles_path para distinguir de las de s.
module ActiveModel
  class Name
    def _singularize(_string, replacement = '_')
      demodulized = ActiveSupport::Inflector.demodulize(self)
      ActiveSupport::Inflector.underscore(demodulized).tr('/', replacement)
    end
  end

  module Naming
    def model_name
      @model_name ||= begin
        namespace = module_parents.find do |n|
          n.respond_to?(:use_relative_model_naming?) && n.use_relative_model_naming?
        end
        ActiveModel::Name.new(self, namespace).tap do |name|
          if respond_to? :naming_overrides
            name.instance_variable_set :@route_key, naming_overrides[:route_key]
            name.instance_variable_set :@singular_route_key,
                                       naming_overrides[:singular_route_key] || naming_overrides[:route_key].singularize
          end
        end
      end
    end
  end
end
