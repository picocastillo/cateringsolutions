require 'rails_helper'

RSpec.describe Cobros::Recibo, type: :model do
  describe 'inheritance' do
    it 'inherits from FlujoEconomico' do
      expect(described_class.superclass).to eq Logistica::Flujos::FlujoEconomico
    end
  end

  describe 'instance methods' do
    let(:recibo) { described_class.new(nro: 123) }

    describe '#to_s' do
      it 'returns nro_completo' do
        expect(recibo.to_s).to eq 'X 123'
      end
    end

    describe '#nro_completo' do
      it 'returns formatted number with X prefix' do
        expect(recibo.nro_completo).to eq 'X 123'
      end

      it 'handles nil nro' do
        recibo.nro = nil
        expect(recibo.nro_completo).to eq 'X 0'
      end
    end

    describe '#nro_formateado' do
      it 'formats number with leading zeros' do
        expect(recibo.nro_formateado).to eq '00000123'
      end

      it 'formats large numbers correctly' do
        recibo.nro = 9_999_999
        expect(recibo.nro_formateado).to eq '09999999'
      end
    end

    describe '#secuenciador' do
      it 'returns tienda-specific sequencer name' do
        recibo.tienda_id = 5
        expect(recibo.secuenciador).to eq 'tienda5_recibos'
      end
    end

    describe '#preparar_afectaciones' do
      let(:tienda) { create(:tienda) }
      let(:cliente) { create(:cliente, tienda: tienda) }
      let(:cuenta) { create(:cuenta, cliente: cliente) }

      let!(:tipo_factura) do
        Comprobantes::Tipo.find_or_create_by!(codigo: 1) do |t|
          t.desc = 'Factura'
          t.clase = 'Ventas::Facturacion::Factura'
          t.letra = 'A'
          t.debitan = true
        end
      end
      let!(:tipo_recibo) do
        Comprobantes::Tipo.find_or_create_by!(codigo: 4) do |t|
          t.desc = 'Recibo'
          t.clase = 'Cobros::Recibo'
          t.letra = 'X'
        end
      end

      let(:usuario) do
        user = create(:usuario, :admin, visualizando_tienda: tienda)
        user.tiendas << tienda unless user.tiendas.include?(tienda)
        user
      end

      it 'responds to preparar_afectaciones' do
        recibo = described_class.new(cuenta: cuenta)
        expect(recibo).to respond_to(:preparar_afectaciones)
      end

      it 'distributes payment across pending facturas' do
        cat = Productos::Categoria.create!(nombre: 'Cat', tienda: tienda)
        prod = Productos::Producto.create!(nombre: 'Prod', categoria: cat, tienda: tienda)

        # Create 2 confirmed facturas
        f1 = Ventas::Facturacion::Factura.create!(
          tienda: tienda, cuenta: cuenta, autor: usuario,
          fecha_emision: Time.current, completar_on_save: true,
          renglones: [{ producto: prod, cantidad: 1, precio_unitario: 500, descripcion: 'Prod' }]
        )
        f1.contabilizar
        f1.estado = :confirmado
        f1.save!

        f2 = Ventas::Facturacion::Factura.create!(
          tienda: tienda, cuenta: cuenta, autor: usuario,
          fecha_emision: Time.current, completar_on_save: true,
          renglones: [{ producto: prod, cantidad: 1, precio_unitario: 300, descripcion: 'Prod' }]
        )
        f2.contabilizar
        f2.estado = :confirmado
        f2.save!

        recibo = described_class.new(cuenta: cuenta, tienda: tienda, autor: usuario)
        medio = Logistica::Flujos::Efectivo.new(importe: 700)
        recibo.efectivos = [medio]
        recibo.preparar_afectaciones

        expect(recibo.afectaciones.size).to eq(2)
        expect(recibo.afectaciones.first.importe.to_f).to eq(500)
        expect(recibo.afectaciones.last.importe.to_f).to eq(200)
      end
    end
  end

  describe 'callbacks' do
    describe '#asignar_tipo' do
      it 'assigns tipo with codigo 4 for new records' do
        tipo = Comprobantes::Tipo.find_or_create_by!(codigo: 4) do |t|
          t.desc = 'Recibo'
          t.clase = 'Cobros::Recibo'
          t.letra = 'X'
        end

        recibo = described_class.new
        recibo.send(:asignar_tipo)
        expect(recibo.tipo).to eq tipo
      end

      it 'does not assign tipo for existing records' do
        recibo = described_class.new
        allow(recibo).to receive(:new_record?).and_return(false)
        recibo.send(:asignar_tipo)
        expect(recibo.tipo).to be_nil
      end
    end
  end
end
