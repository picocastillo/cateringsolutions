module Cupones
  class Cupon < ApplicationRecord
    self.table_name = 'cupones'

    belongs_to :tienda, class_name: 'Tiendas::Tienda'
    has_one :pedido, class_name: 'Pedidos::Pedido'

    validates :codigo, presence: true, uniqueness: true
    validates :tipo_descuento, presence: true, inclusion: { in: ['importe', 'porcentaje'] }
    validates :importe, presence: true, numericality: { greater_than: 0 }, if: -> { tipo_descuento == 'importe' }
    validates :porcentaje, presence: true, numericality: { greater_than: 0, less_than_or_equal_to: 100 }, if: -> { tipo_descuento == 'porcentaje' }
    validates :limite_bonificacion, presence: true, numericality: { greater_than: 0 }, if: -> { tipo_descuento == 'porcentaje' }

    before_validation :generar_codigo, on: :create
    before_destroy :verificar_no_usado
    after_save :asegurar_fecha_vencimiento

    scope :del_grupo, ->(grupo) { where(grupo: grupo) }
    scope :no_usados, -> { where.not(id: Pedidos::Pedido.where.not(cupon_id: nil).select(:cupon_id)) }
    scope :vigentes, -> { no_usados.where(cancelado: false).where(fecha_vencimiento: Date.current..) }

    ESTADOS = ['vigente', 'vencido', 'usado', 'cancelado'].freeze

    def to_s
      codigo
    end

    def vencido?
      !cancelado? && !usado? && fecha_vencimiento.present? && fecha_vencimiento < Date.current
    end

    def usado?
      pedido.present?
    end

    def vigente?
      !usado? && !cancelado? && !vencido?
    end

    def eliminable?
      !usado?
    end

    def estado_texto
      return 'Cancelado' if cancelado?
      return 'Usado' if usado?
      return 'Vencido' if vencido?

      'Vigente'
    end

    def cancelar!
      raise 'Solo cupones vigentes pueden ser cancelados' unless vigente?

      update!(cancelado: true)
    end

    def usar!(pedido)
      raise 'Solo cupones vigentes pueden ser usados' unless vigente?

      pedido.update!(cupon: self)
    end

    def descuento_para(importe_total)
      if tipo_descuento == 'importe'
        [importe, importe_total].min
      else
        [importe_total * porcentaje / 100.0, limite_bonificacion].min
      end
    end

    def descuento_descripcion
      if tipo_descuento == 'importe'
        "$#{importe.to_i == importe ? importe.to_i : importe}"
      else
        lim = limite_bonificacion.to_i == limite_bonificacion ? limite_bonificacion.to_i : limite_bonificacion
        pct = porcentaje.to_i == porcentaje ? porcentaje.to_i : porcentaje
        "#{pct}% (máx $#{lim})"
      end
    end

    def self.expirar_grupo!(grupo)
      del_grupo(grupo).update_all(fecha_vencimiento: Date.current - 1.day)
    end

    def self.eliminar_grupo!(grupo)
      del_grupo(grupo).no_usados.destroy_all
    end

    def self.cancelar_grupo!(grupo)
      del_grupo(grupo).vigentes.update_all(cancelado: true)
    end

    def self.crear_cantidad(cantidad, attrs)
      grupo = SecureRandom.uuid
      cantidad.times.map do
        create!(attrs.merge(grupo: grupo))
      end
    end

    def self.buscar_vigente(codigo, tienda)
      cupon = find_by(codigo: codigo.to_s.strip.upcase, tienda: tienda, cancelado: false)
      return nil if cupon.nil? || cupon.usado? || cupon.vencido?

      cupon
    end

    def self.eliminar_masivo(codigo: nil, grupo: nil)
      scope = all
      scope = scope.where(codigo: codigo.to_s.strip.upcase) if codigo.present?
      scope = scope.where('grupo LIKE ?', "#{grupo.strip}%") if grupo.present?
      scope.no_usados.destroy_all
    end

    private

    def generar_codigo
      return if codigo.present?

      self.codigo = SecureRandom.alphanumeric(8).upcase
    end

    def asegurar_fecha_vencimiento
      return if fecha_vencimiento.present? && fecha_vencimiento >= Date.current

      update_column(:fecha_vencimiento, Date.current + 3.months)
    end

    def verificar_no_usado
      return unless usado?

      errors.add(:base, 'No se puede eliminar un cupón utilizado por un pedido')
      throw(:abort)
    end
  end
end
