module Productos
  class Precio < ApplicationRecord
    acts_as_discontinued

    has_and_belongs_to_many :clientes, class_name: 'Clientes::Cliente', join_table: 'clientes_precios',
                                       association_foreign_key: 'cliente_id', optional: true
    belongs_to :producto, class_name: 'Productos::Producto'

    before_validation :asignar_fecha_desde_por_defecto, on: :create

    validates :importe, :fecha_desde, presence: true

    validates :importe, numericality: { greater_than: 0 }

    def vigente?(f = Time.zone.today)
      fecha_desde <= f && (!fecha_hasta || fecha_hasta >= f)
    end

    def activo_a?(c_ids)
      cls = Clientes::Cliente.where(id: c_ids).to_a
      vigente? && (clientes.blank? || clientes.any? { |c| cls.include?(c) })
    end

    def to_s
      "#{producto} $#{importe}"
    end

    def nombre_codigos_y_precio(md = nil)
      n = md ? "#{producto} - #{md.descripcion.capitalize}" : producto.to_s
      c = " <span style='color: #aaa;'>C #{producto.codigo}</span>"

      "<div class='row'>" \
        "<div class='col-sm-7 col-md-7'>#{n}</div>" \
        "<div class='col-sm-3 col-md-3' style='text-align:left;white-space: nowrap;'>" \
        "<div>#{c}</div></div>" \
        "<div class='col-sm-2 col-md-2' style='text-align:right'>#{Danconia::Money.new(importe)}</div>"
    end

    def nombre_corto_y_precio(md = nil)
      n = md ? md.descripcion.capitalize.to_s : producto.to_s
      "<div class='row'><div class='col-9'><span class='desc'>#{n}</span></div><div class='col-3' style='text-align:right;margin-left:-15px'>#{Danconia::Money.new(importe)}</div>"
    end

    private

    def asignar_fecha_desde_por_defecto
      self.fecha_desde = Time.zone.today if fecha_desde.blank? && importe.present?
    end
  end
end
