require 'rails_helper'

RSpec.describe Productos::StockMovimiento, type: :model do
  let(:tienda) { create(:tienda) }
  let(:producto) { create(:producto, tienda: tienda) }
  let(:stock) { producto.stocks.first }

  describe 'associations' do
    it { is_expected.to belong_to(:stock).class_name('Productos::Stock') }
    it { is_expected.to belong_to(:usuario).class_name('Usuarios::Usuario').optional }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:tipo) }
    it { is_expected.to validate_presence_of(:cantidad) }
    it { is_expected.to validate_presence_of(:cantidad_anterior) }
    it { is_expected.to validate_presence_of(:cantidad_nueva) }

    it 'sets default fecha before validation' do
      movimiento = build(:stock_movimiento, stock: stock, fecha: nil)
      expect(movimiento).to be_valid
      expect(movimiento.fecha).to be_present
    end

    it { is_expected.to validate_inclusion_of(:tipo).in_array(['entrada', 'salida', 'ajuste_entrada', 'ajuste_salida', 'venta', 'devolucion', 'transferencia']) }
    it { is_expected.to validate_numericality_of(:cantidad).is_greater_than(0) }
    it { is_expected.to validate_numericality_of(:cantidad_anterior).is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_numericality_of(:cantidad_nueva).is_greater_than_or_equal_to(0) }
  end

  describe 'scopes' do
    let!(:entrada) { create(:stock_movimiento, stock: stock, tipo: 'entrada', fecha: 3.days.ago, usuario: nil) }
    let!(:salida) { create(:stock_movimiento, stock: stock, tipo: 'salida', fecha: 2.days.ago, usuario: nil) }
    let!(:ajuste_entrada) { create(:stock_movimiento, stock: stock, tipo: 'ajuste_entrada', fecha: 1.day.ago, usuario: nil) }
    let!(:venta) { create(:stock_movimiento, stock: stock, tipo: 'venta', fecha: Time.current, usuario: nil) }

    it '.entradas returns entry movements' do
      expect(described_class.entradas).to include(entrada, ajuste_entrada)
      expect(described_class.entradas).not_to include(salida, venta)
    end

    it '.salidas returns exit movements' do
      expect(described_class.salidas).to include(salida, venta)
      expect(described_class.salidas).not_to include(entrada, ajuste_entrada)
    end

    it '.por_tipo filters by movement type' do
      expect(described_class.por_tipo('entrada')).to include(entrada)
      expect(described_class.por_tipo('entrada')).not_to include(salida)
    end

    it '.recientes orders by fecha desc' do
      older = create(:stock_movimiento, stock: stock, fecha: 2.days.ago, usuario: nil)
      newer = create(:stock_movimiento, stock: stock, fecha: 1.hour.from_now, usuario: nil)

      recientes = described_class.where(id: [older.id, newer.id]).recientes
      expect(recientes.first).to eq(newer)
      expect(recientes.last).to eq(older)
    end
  end

  describe 'instance methods' do
    context 'for entrada movements' do
      let(:movimiento) { create(:stock_movimiento, stock: stock, tipo: 'entrada', cantidad: 10, usuario: nil) }

      it '#entrada? returns true' do
        expect(movimiento.entrada?).to be true
      end

      it '#salida? returns false' do
        expect(movimiento.salida?).to be false
      end

      it '#diferencia returns positive value' do
        expect(movimiento.diferencia).to eq(10)
      end
    end

    context 'for salida movements' do
      let(:movimiento) { create(:stock_movimiento, stock: stock, tipo: 'venta', cantidad: 5, usuario: nil) }

      it '#entrada? returns false' do
        expect(movimiento.entrada?).to be false
      end

      it '#salida? returns true' do
        expect(movimiento.salida?).to be true
      end

      it '#diferencia returns negative value' do
        expect(movimiento.diferencia).to eq(-5)
      end
    end

    it '#producto returns associated product' do
      movimiento = create(:stock_movimiento, stock: stock, usuario: nil)
      expect(movimiento.producto).to eq(producto)
    end

    it '#tienda returns associated tienda' do
      movimiento = create(:stock_movimiento, stock: stock, usuario: nil)
      expect(movimiento.tienda).to eq(tienda)
    end
  end

  describe 'class methods' do
    let!(:movimiento1) { create(:stock_movimiento, stock: stock, tipo: 'entrada', cantidad: 10, usuario: nil) }
    let!(:movimiento2) { create(:stock_movimiento, stock: stock, tipo: 'salida', cantidad: 3, usuario: nil) }
    let!(:movimiento3) { create(:stock_movimiento, stock: stock, tipo: 'venta', cantidad: 2, usuario: nil) }

    describe '.resumen_movimientos' do
      it 'returns movement summary for stock' do
        result = described_class.resumen_movimientos(stock.id)

        expect(result[:total_entradas]).to eq(10)
        expect(result[:total_salidas]).to eq(5)
        expect(result[:cantidad_movimientos]).to eq(3)
        expect(result[:ultimo_movimiento]).to be_present
      end

      it 'filters by date range when provided' do
        desde = 1.day.ago
        hasta = 1.hour.from_now

        result = described_class.resumen_movimientos(stock.id, desde, hasta)
        expect(result[:cantidad_movimientos]).to eq(3)
      end
    end

    describe '.reporte_por_producto' do
      it 'returns movement report by product' do
        result = described_class.reporte_por_producto(producto.id)

        expect(result['entrada']).to eq(10)
        expect(result['salida']).to eq(3)
        expect(result['venta']).to eq(2)
      end
    end

    describe '.movimientos_por_tienda' do
      it 'returns movements for tienda' do
        result = described_class.movimientos_por_tienda(tienda.id)
        expect(result.count).to eq(3)
        expect(result).to include(movimiento1, movimiento2, movimiento3)
      end
    end
  end

  describe 'callbacks' do
    it 'sets default fecha before validation' do
      movimiento = build(:stock_movimiento, stock: stock, fecha: nil)
      movimiento.valid?
      expect(movimiento.fecha).to be_present
    end
  end
end
