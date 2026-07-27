module Productos
  class Categoria < ApplicationRecord
    acts_as_discontinued

    has_and_belongs_to_many :clientes, class_name: 'Clientes::Cliente', join_table: 'clientes_categorias',
                                       association_foreign_key: 'cliente_id'

    has_many :productos, -> { order :nombre }, class_name: 'Productos::Producto', foreign_key: 'categoria_id'

    belongs_to :grupo_cocina, class_name: 'Productos::GrupoCocina', optional: true

    belongs_to :tienda, class_name: 'Tiendas::Tienda'

    validates :nombre, uniqueness: { scope: :tienda_id }
    validates :nombre, presence: true

    scope :vendibles_en_carrito, -> { where(vender_en_carrito: true) }

    before_create :asignar_codigo

    def productos_activos
      productos.active
    end

    def to_s
      nombre
    end

    def grupo
      grupo_cocina || Productos::GrupoCocina.new(nombre: 'Sin Grupo')
    end

    def to_s_label
      f = <<-HTML
        <div class="label" style="color: #{color_safe}">
          <span>#{nombre}</span>
        </div>
      HTML
      f.html_safe
    end

    private

    def asignar_codigo
      return if codigo.present?

      self.codigo = Infraestructura::GeneradorSecuencial.proximo("tienda#{tienda_id}_categorias-venta")
    end
  end
end
