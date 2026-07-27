module Locales
  class Local < ApplicationRecord
    extend Memoist

    has_many :usuarios, class_name: 'Usuarios::Usuario'
    has_many :documentos, lambda {
      order(:position).where('documento_content_type like "%image%"')
    }, as: :documentable, dependent: :destroy, class_name: 'Infraestructura::Documento'
    belongs_to :tienda, class_name: 'Tiendas::Tienda', optional: false

    validates :nombre, presence: true
    validates :domicilio, presence: true
    validates :telefono, presence: true

    def nombre_y_domicilio
      "#{nombre}: #{domicilio}"
    end

    def to_s
      nombre
    end
  end
end
