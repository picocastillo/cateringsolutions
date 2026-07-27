module Productos
  class Producto < ApplicationRecord
    acts_as_discontinued
    extend Memoist

    validates :nombre, uniqueness: { scope: :tienda_id }
    validates :codigo, uniqueness: { scope: :tienda_id, unless: :new_record? }
    validates :nombre, presence: true
    validate :codigos_externos_validos_para_barcode
    validate :pesable_no_modificable_si_en_uso

    has_and_belongs_to_many :pedidos, class_name: 'Productos::Pedido'
    belongs_to :categoria, class_name: 'Productos::Categoria'

    has_many :documentos, -> { order :position }, as: :documentable, dependent: :destroy, class_name: 'Infraestructura::Documento'
    has_many :imagenes, lambda {
      order(:position).where('documento_content_type like "%image%"')
    }, as: :documentable, dependent: :destroy, class_name: 'Infraestructura::Documento'

    belongs_to :tienda, class_name: 'Tiendas::Tienda'

    has_and_belongs_to_many :menus_diarios, class_name: 'MenusDiarios::MenuDiario',
                                            join_table: 'menus_diarios_productos',
                                            association_foreign_key: 'menu_diario_id', order: 'productos.id'

    has_many :precios, -> { order :fecha_desde }, dependent: :destroy, autosave: true,
                                                  class_name: 'Productos::Precio', foreign_key: :producto_id,
                                                  after_add: ->(t, i) { i.producto = t }
    accepts_nested_attributes_for :precios, reject_if: lambda { |a|
      a['importe'].blank? || a['importe'].to_f == 0.0
    }, allow_destroy: true

    has_many :stocks, dependent: :destroy, class_name: 'Productos::Stock'
    has_many :stock_movimientos, through: :stocks, class_name: 'Productos::StockMovimiento'

    before_create :asignar_codigo
    after_create :crear_stock_inicial
    after_create :asignar_mostrar_como_nuevo

    attr_accessor :precio_actual

    def to_s
      nombre
    end

    def self.find_by_codigos(c)
      return if c.blank?

      codigo_eq(c).min_by { |a| a.codigo == c ? 0 : 1 }
    end

    def self.codigo_eq(codigo)
      cs = codigo.to_s.split_csv
      ids_ci = where(codigo: cs).pluck(:id)
      ids_ce = where(codigos_externos: cs).pluck(:id)
      where id: ids_ci + ids_ce
    end

    def codigo_y_nombre
      format('%<codigo>s - %<nombre>s', codigo: codigo, nombre: nombre)
    end

    def color_safe
      invalid_colors = ['#000', '#000000', '#fff', '#ffffff']
      color.present? && invalid_colors.exclude?(color) ? color : '#989898'
    end

    def togle_favorito(usuario)
      a = Productos::Favorito.where(usuario_id: usuario.id, producto_id: id).first
      a.present? ? a.destroy! : Productos::Favorito.create(usuario_id: usuario.id, producto_id: id)
    end

    def imagen_principal
      imagenes.first ? imagenes.first.url(:thumb) : '/tenedores.png'
    end

    def buscar_precio(cliente, f)
      return unless f

      f = f.to_date
      # Single query: find the best matching precio for this cliente
      # Priority: client-specific price (highest importe), then universal price (no clients assigned)
      cliente_precio = Precio
                       .joins("INNER JOIN clientes_precios ON clientes_precios.precio_id = precios.id AND clientes_precios.cliente_id = #{cliente.id}")
                       .where(producto_id: id)
                       .where('precios.fecha_desde <= ? AND (precios.fecha_hasta >= ? OR precios.fecha_hasta IS NULL)', f, f)
                       .order(importe: :desc)
                       .first

      return cliente_precio if cliente_precio || cliente.listas_de_precio_privada?

      # Fallback: universal price (precio with no clients assigned)
      Precio
        .where(producto_id: id)
        .where('precios.fecha_desde <= ? AND (precios.fecha_hasta >= ? OR precios.fecha_hasta IS NULL)', f, f)
        .where('NOT EXISTS (SELECT 1 FROM clientes_precios WHERE clientes_precios.precio_id = precios.id)')
        .order(importe: :desc)
        .first
    end
    memoize :buscar_precio

    def precios_vigentes(fecha = Time.zone.today)
      f = fecha.to_date
      precios.where('precios.fecha_desde <= ? and (precios.fecha_hasta >= ? or precios.fecha_hasta is null)', f,
                    f).order('precios.fecha_desde desc')
    end
    memoize :precios_vigentes

    def precio_promedio
      precios_vigentes.average(:importe)
    end
    memoize :precio_promedio

    def asignar_codigo
      return if codigo.present?

      1000.times do
        candidato = Infraestructura::GeneradorSecuencial.proximo("tienda#{tienda_id}_productos-venta")
        unless Producto.exists?(tienda_id: tienda_id, codigo: candidato)
          self.codigo = candidato
          return
        end
        Rails.logger.warn "Codigo #{candidato} ya existe para tienda #{tienda_id}, intentando siguiente"
      end
      raise "No se pudo asignar codigo único para tienda #{tienda_id} después de 1000 intentos"
    end

    # Stock management methods
    def stock_actual(local_id = nil)
      stock_for_local(local_id)&.cantidad_actual || 0
    end

    def stock_disponible?(cantidad_requerida, local_id = nil)
      stock_actual(local_id) >= cantidad_requerida
    end

    def stock_for_local(local_id = nil)
      # Only return stock if category has stock_activo
      return nil unless categoria&.stock_activo?

      # Use loaded association if already eager-loaded to avoid N+1
      if stocks.loaded?
        stocks.detect { |s| s.local_id == local_id } || ensure_stock_exists(local_id)
      else
        stocks.find_by(local_id: local_id) || ensure_stock_exists(local_id)
      end
    end

    def ensure_stock_exists(local_id = nil)
      # Only create stock if category has stock_activo
      return nil unless categoria&.stock_activo?

      stocks.find_or_create_by!(
        tienda: tienda,
        local_id: local_id
      ) do |stock|
        stock.cantidad_actual = 0
        stock.cantidad_minima = 0
        stock.activo = true
      end
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error "Error ensuring stock exists for producto #{id}, local #{local_id}: #{e.message}"
      nil
    end

    def stock_principal
      stock_for_local(nil)
    end

    def tiene_stock?(local_id = nil)
      stock_actual(local_id).positive?
    end

    def stock_bajo?(local_id = nil)
      stock = stock_for_local(local_id)
      stock&.stock_bajo? || false
    end

    def stock_critico?(local_id = nil)
      stock = stock_for_local(local_id)
      stock&.stock_critico? || false
    end

    def nuevo?
      mostrar_como_nuevo_hasta.present? && mostrar_como_nuevo_hasta >= Date.current
    end

    def reducir_stock(cantidad, local_id = nil, motivo = 'venta')
      stock = stock_for_local(local_id)
      return false unless stock

      stock.reducir_stock(cantidad, motivo)
    end

    def aumentar_stock(cantidad, local_id = nil, motivo = 'reposicion')
      stock = stock_for_local(local_id)
      return false unless stock

      stock.aumentar_stock(cantidad, motivo)
    end

    def pesable_bloqueado?
      return false if new_record?

      categoria&.stock_activo? && stocks.where('cantidad_actual != 0').exists?
    end

    private

    def asignar_mostrar_como_nuevo
      update_column(:mostrar_como_nuevo_hasta, Date.current + 1.month)
    end

    def codigos_externos_validos_para_barcode
      return if codigos_externos.blank?

      codigos_externos.split(',').each do |codigo_ext|
        unless codigo_ext.strip.match?(%r{\A[A-Z0-9\-. $/+%]+\z}i)
          errors.add(:codigos_externos, "contiene caracteres inválidos en '#{codigo_ext.strip}'. Solo se permiten letras, números y los caracteres - . $ / + %")
        end
      end
    end

    def pesable_no_modificable_si_en_uso
      # Workaround: parallel test workers may have stale schema cache where pesable_changed? is undefined
      return unless Rails.env.test? ? (has_attribute?(:pesable) && attribute_changed?(:pesable)) : pesable_changed?
      return if new_record?

      return unless pesable_bloqueado?

      errors.add(:pesable, 'no se puede modificar porque el producto tiene stock o pedidos asociados')
    end

    def crear_stock_inicial
      # Skip if stocks already exist (e.g., from factory)
      return if stocks.any?

      # Only create stock if category has stock_activo enabled
      return unless categoria&.stock_activo?

      # Crear stock principal (sin local específico)
      stocks.create!(
        tienda: tienda,
        local_id: nil,
        cantidad_actual: 0,
        cantidad_minima: 0,
        activo: true
      )

      # Si la tienda tiene múltiples locales, crear stocks para cada local
      if tienda&.multiple_locales?
        tienda.locales.each do |local|
          stocks.create!(
            tienda: tienda,
            local: local,
            cantidad_actual: 0,
            cantidad_minima: 0,
            activo: true
          )
        end
      end
    rescue StandardError => e
      Rails.logger.error "Error creando stock inicial para producto #{id}: #{e.message}"
    end
  end
end
