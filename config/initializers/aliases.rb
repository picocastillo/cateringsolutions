# Legacy constant aliasing disabled for Ruby 3.x/Rails 7 upgrade compatibility
# The const_missing hook conflicts with Zeitwerk autoloading
#
# module AliasConstMissing
#   GlobalAliases = [
#     'Clientes::Cliente',
#     'Productos::Producto',
#     'Productos::Categoria',
#     'Clientes::Cliente',
#     'Usuarios::Usuario',
#     'Usuarios::Rol',
#     'Referencia::Provincia',
#     'Infraestructura::Documento'
#   ].index_by(&:demodulize).merge 'Tag' => 'ActsAsTaggableOn::Tag',
#                                  'Money' => 'Danconia::Money', 'Pedido' => 'Pedidos::Pedido'
#
#   def const_missing(name)
#     name = name.to_s
#     if (a = GlobalAliases[name])
#       if a.is_a? String
#         GlobalAliases[name] = a.constantize
#       else
#         a
#       end
#     else
#       super
#     end
#   end
#
#   ActiveSupport::Reloader.to_prepare do
#     GlobalAliases.each { |k, v| GlobalAliases[k] = v.to_s }
#   end
# end
#
# Object.extend AliasConstMissing
