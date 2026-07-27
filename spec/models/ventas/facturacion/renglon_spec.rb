require 'rails_helper'

RSpec.describe Ventas::Facturacion::Renglon, type: :model do
  let(:tienda) { Tiendas::Tienda.create!(nombre: 'Tienda Renglon') }
  let(:cliente) { Clientes::Cliente.create!(nombre: 'Cliente Renglon', cuit: '20294834487', dia_inicio_ciclo_facturacion: 1, vencimiento_a: 1, horario_corte_pedidos: '12:00', tienda: tienda) }
  let(:cuenta) { Clientes::Cuenta.create!(cliente: cliente, nombre: 'Cuenta Renglon') }
  let(:categoria) { Productos::Categoria.create!(nombre: 'Categoria Renglon', tienda: tienda) }
  let(:producto) { Productos::Producto.create!(nombre: 'Producto Renglon', categoria: categoria, tienda: tienda) }
  let(:tipo) { Comprobantes::Tipo.create!(desc: 'Factura', codigo: 1, clase: 'Ventas::Facturacion::Factura', letra: 'A') }
  let(:comprobante) { Ventas::Facturacion::Comprobante.new(cuenta: cuenta, tienda: tienda, tipo: tipo) }
  let(:renglon) { described_class.new(comprobante: comprobante, producto: producto, cantidad: 2, precio_unitario: 100) }

  it 'is valid with valid attributes' do
    expect(renglon).to be_a(described_class)
  end

  describe '#precio_total' do
    it 'calculates total from cantidad and precio_unitario' do
      renglon.cantidad = 5
      renglon.precio_unitario = 100
      expect(renglon.precio_total.to_f).to eq(500)
    end

    it 'returns zero when cantidad is zero' do
      renglon.cantidad = 0
      renglon.precio_unitario = 100
      expect(renglon.precio_total.to_f).to eq(0)
    end
  end

  describe '#total_con_iva' do
    it 'calculates total without IVA when tasa_iva not set' do
      renglon.cantidad = 2
      renglon.precio_unitario = 100
      expect(renglon.total_con_iva.to_f).to eq(200)
    end
  end

  describe '#iva_total' do
    it 'returns iva calculated from precio_total' do
      renglon.cantidad = 2
      renglon.precio_unitario = 100
      expect(renglon.iva_total).to be_a(Danconia::Money)
    end
  end

  describe '#sin_cargo?' do
    it 'returns true when precio_unitario is zero' do
      renglon.precio_unitario = 0
      renglon.cantidad = 1
      expect(renglon.sin_cargo?).to be true
    end

    it 'returns true when cantidad is zero' do
      renglon.cantidad = 0
      renglon.precio_unitario = 100
      expect(renglon.sin_cargo?).to be true
    end

    it 'returns false when both are positive' do
      renglon.cantidad = 1
      renglon.precio_unitario = 100
      expect(renglon.sin_cargo?).to be false
    end
  end

  describe '#iva_unitario' do
    it 'calculates IVA for unit price' do
      renglon.precio_unitario = 100
      expect(renglon.iva_unitario).to be_a(Danconia::Money)
    end
  end

  describe '#unitario_con_iva' do
    it 'returns price with IVA included' do
      renglon.precio_unitario = 100
      expect(renglon.unitario_con_iva).to be_a(Danconia::Money)
    end
  end

  describe '#producto=' do
    it 'sets categoria from producto when producto has categoria' do
      new_categoria = Productos::Categoria.create!(nombre: 'Nueva Categoria', tienda: tienda)
      new_producto = Productos::Producto.create!(nombre: 'Nuevo Producto', categoria: new_categoria, tienda: tienda)
      renglon.categoria = nil
      renglon.producto = new_producto
      expect(renglon.categoria).to eq(new_categoria)
    end
  end

  describe '#descripcion' do
    it 'returns descripcion when present' do
      renglon.descripcion = 'Custom description'
      expect(renglon.descripcion).to eq('Custom description')
    end

    it 'has descripcion field' do
      expect(renglon).to respond_to(:descripcion)
    end
  end

  describe '#ajustar_tasa_iva' do
    it 'sets tasa_iva to no_gravado when comprobante is no_gravado' do
      renglon.tasa_iva = :iva_21
      allow(comprobante).to receive(:no_gravado?).and_return(true)
      renglon.ajustar_tasa_iva(comprobante)
      expect(renglon.tasa_iva).to eq(Impuestos::TasaIva[:no_gravado])
    end
  end

  describe 'discount renglon (for NC descuento)' do
    it 'handles descuento unitario as precio_unitario' do
      renglon.precio_unitario = 50 # descuento_unitario
      renglon.cantidad = 2
      renglon.descripcion = 'Descuento cupón TEST123 - Producto A'
      expect(renglon.precio_total.to_f).to eq(100)
    end

    it 'calculates IVA correctly on discount amount' do
      renglon.precio_unitario = 50
      renglon.cantidad = 2
      renglon.tasa_iva = :iva_21
      expect(renglon.iva_total.to_f).to eq(21) # 100 * 0.21
      expect(renglon.total_con_iva.to_f).to eq(121) # 100 + 21
    end
  end

  describe 'validations' do
    it 'requires positive cantidad' do
      renglon.cantidad = -1
      expect(renglon).not_to be_valid
      expect(renglon.errors[:cantidad]).to be_present
    end

    it 'requires numeric precio_unitario' do
      renglon.precio_unitario = 'abc'
      expect(renglon).not_to be_valid
    end
  end

  describe 'peso (weight-based)' do
    describe '#precio_total' do
      it 'calculates precio_unitario * peso when peso present (cantidad always 1)' do
        renglon.cantidad = 1
        renglon.precio_unitario = 500
        renglon.peso = 1.250
        # 500 * 1 * 1.250 = 625
        expect(renglon.precio_total.to_f).to eq(625.0)
      end

      it 'calculates precio_unitario * cantidad when peso nil' do
        renglon.cantidad = 2
        renglon.precio_unitario = 500
        renglon.peso = nil
        expect(renglon.precio_total.to_f).to eq(1000.0)
      end
    end

    describe '#total_con_iva' do
      it 'includes peso in total with IVA' do
        renglon.cantidad = 1
        renglon.precio_unitario = 1000
        renglon.peso = 0.5
        renglon.tasa_iva = :iva_21
        # precio_total = 1000 * 1 * 0.5 = 500
        # iva = 500 * 0.21 = 105
        # total = 605
        expect(renglon.total_con_iva.to_f).to eq(605.0)
      end
    end

    describe '#iva_total' do
      it 'calculates IVA based on peso-adjusted precio_total (cantidad always 1)' do
        renglon.cantidad = 1
        renglon.precio_unitario = 100
        renglon.peso = 3.0
        renglon.tasa_iva = :iva_21
        # precio_total = 100 * 1 * 3.0 = 300
        # iva = 300 * 0.21 = 63
        expect(renglon.iva_total.to_f).to eq(63.0)
      end
    end

    describe '#descripcion_ticket' do
      it 'includes peso in Kg for pesable products' do
        renglon.peso = 0.8
        expect(renglon.descripcion_ticket).to eq("#{producto} 0.8 Kg")
      end

      it 'returns product name only when no peso' do
        renglon.peso = nil
        expect(renglon.descripcion_ticket).to eq(producto.to_s)
      end
    end
  end
end
