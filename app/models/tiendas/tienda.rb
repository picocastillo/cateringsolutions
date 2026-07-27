module Tiendas
  class Tienda < ApplicationRecord
    acts_as_discontinued

    validates :nombre, presence: true
    validates :nombre, uniqueness: { case_sensitive: false }

    has_and_belongs_to_many :usuarios, class_name: 'Usuarios::Usuario', join_table: 'usuarios_tiendas',
                                       association_foreign_key: 'usuario_id', order: 'usuarios.nombre'

    # Step 2 of shared-clientes migration: explicit clientes ↔ tiendas access list.
    has_and_belongs_to_many :clientes, class_name: 'Clientes::Cliente', join_table: 'clientes_tiendas',
                                       association_foreign_key: 'cliente_id'

    has_many :documentos, lambda {
      order(:position).where('documento_content_type like "%image%"')
    }, as: :documentable, dependent: :destroy, class_name: 'Infraestructura::Documento'
    has_many :locales, class_name: 'Locales::Local'
    belongs_to :local_atencion_carrito, class_name: 'Locales::Local', optional: true

    before_save :reset_colors

    def local_para_carrito
      local_atencion_carrito || locales.first
    end

    # True if the "más productos" carrito panel should be rendered, considering
    # both the legacy `muestra_mas_productos` flag and the new
    # `muestra_mas_productos_por_categoria` override.
    def muestra_mas_productos_efectivo?
      muestra_mas_productos? || muestra_mas_productos_por_categoria?
    end

    # When `muestra_mas_productos_por_categoria` is enabled the panel only
    # shows categorias whose `vender_en_carrito` flag is true. Otherwise the
    # scope is returned unchanged (legacy behaviour: all categorias).
    def filtrar_categorias_para_carrito(scope)
      return scope unless muestra_mas_productos_por_categoria?

      scope.where(vender_en_carrito: true)
    end

    def to_s
      nombre
    end

    def iniciales
      names = nombre.split
      names.pluck(0).map(&:capitalize).join('.')
    end

    # Send daily stock alerts email
    def self.enviar_alertas_stock
      Tienda.active.each do |tienda|
        next if tienda.stock_notifications_email.blank?

        begin
          mail = StockAlertsMailer.daily_report(tienda)
          if mail && !mail.is_a?(ActionMailer::Base::NullMail)
            mail.deliver_now
            Rails.logger.info "Stock alerts sent for tienda: #{tienda.nombre}"
          end
        rescue StandardError => e
          Rails.logger.error "Failed to send stock alerts for tienda #{tienda.nombre}: #{e.message}"
        end
      end
    end

    private

    def reset_colors
      # Use Tienda 1 (Catering Solutions) default colors instead of nil
      self.color_de_menu = '#c1c1c1' if color_de_menu == '#000000'
      self.color_de_fondo = '#fbfbfb' if color_de_fondo == '#000000'
      self.color_fondo_logo = '#f2f2f2' if color_fondo_logo == '#000000'
      self.color_barra_filtros = '#5c9bd2' if color_barra_filtros == '#000000'
      self.color_links = nil if color_links == '#000000'
      self.color_links_hover = nil if color_links_hover == '#000000'
      self.color_titulo = '#1c1c1c' if color_titulo == '#000000'
      self.color_barra_superior = '#f2f2f2' if color_barra_superior == '#000000'
    end
  end
end
