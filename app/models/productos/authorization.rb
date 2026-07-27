module Productos
  class Authorization < Ability::Subrules
    def add_rules
      cannot(:xls_index, Producto)
      can(:json_index, Producto) { |x| x.tienda == user.tienda_activa }

      if admin?
        can(:manage, Producto) { |x| x.tienda == user.tienda_activa }
        can(:manage, Categoria) { |x| x.tienda == user.tienda_activa }
        can(:manage, GrupoCocina) { |x| x.tienda == user.tienda_activa }
        can(:index, Precio)
        can(:xls_index, Producto)
        can(:index, :etiqueta_producto)

        # Stock management only available for tiendas with maneja_stock enabled
        if user.tienda_activa&.maneja_stock?
          can(:manage, Stock) { |x| x.tienda == user.tienda_activa }
          can(:xls_index, Stock)
          can(:import, Stock)
        end
      elsif rol?(:gestiona_productos)
        can(:index, Precio) { |x| x.tienda == user.tienda_activa }
        can(:index, Producto) { |x| x.tienda == user.tienda_activa }
        can(:xls_index, Producto)
        can(:destroy, Producto) { |x| x.tienda == user.tienda_activa }
        can(:destroy, Categoria) { |x| x.tienda == user.tienda_activa }
        can(:change, Producto) { |x| x.tienda == user.tienda_activa }
        can(:change, Categoria) { |x| x.tienda == user.tienda_activa }
        can(:destroy, GrupoCocina) { |x| x.tienda == user.tienda_activa }
        can(:change, GrupoCocina) { |x| x.tienda == user.tienda_activa }
      end
    end
  end
end
