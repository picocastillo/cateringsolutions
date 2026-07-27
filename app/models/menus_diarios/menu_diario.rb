module MenusDiarios
  class MenuDiario < ApplicationRecord
    has_and_belongs_to_many :productos, class_name: 'Productos::Producto', join_table: 'menus_diarios_productos',
                                        association_foreign_key: 'producto_id', order: 'productos.id'

    belongs_to :autor, class_name: 'Usuarios::Usuario'

    belongs_to :tienda, class_name: 'Tiendas::Tienda'

    enum :tipo, class_name: 'MenusDiarios::Tipo', default: 1

    scope :menu_diario,       -> { where(tipo_id: MenusDiarios::Tipo[:menu_diario].id) }
    scope :productos_diarios, -> { where(tipo_id: MenusDiarios::Tipo[:productos_diarios].id) }

    validates :fecha, :productos, :descripcion, presence: true

    validate :menus_unicos
    validate :productos_acordes_al_tipo

    def to_s
      s = productos.map(&:to_s)
      s << descripcion
      s.join(': ')
    end

    def to_s_horario
      "#{productos.map(&:to_s).join(', ')} el #{fecha}"
    end

    def to_s_growl
      to_s
    end

    def menus_unicos
      return if productos.blank?

      repetidos = MenuDiario.joins(:productos)
                            .where(productos: { id: productos.map(&:id) })
                            .where(fecha: fecha, tipo_id: tipo_id)
      repetidos = repetidos.where.not(id: id) if persisted?
      repetidos = repetidos.distinct.to_a
      return if repetidos.blank?

      categorias = productos.map { |p| p.categoria&.nombre }.compact.uniq.join(', ')
      repetidos_str = repetidos.map { |x| "'#{x.descripcion}'" }.join(', ')
      errors.add :base, "Ya existe un men\u00fa para el d\u00eda #{fecha} con productos de #{categorias}: #{repetidos_str}"
    end

    # Productos belonging to a "menu del día" categoria are reserved for menus
    # of tipo `menu_diario`; everything else is reserved for `productos_diarios`.
    def productos_acordes_al_tipo
      return if productos.blank?

      es_menu_diario = tipo_id == MenusDiarios::Tipo[:menu_diario].id
      invalidos = productos.reject do |p|
        es_menu_diario ? p.categoria&.menu_diario : !p.categoria&.menu_diario
      end
      return if invalidos.empty?

      msg = if es_menu_diario
              'sólo pueden ser productos de categorías "Menú del día"'
            else
              'no pueden ser productos de categorías "Menú del día"'
            end
      errors.add :productos, "#{msg}: #{invalidos.map(&:to_s).join(', ')}"
    end
  end
end
