require 'rails_helper'

RSpec.describe Pedidos::TurnoEntrega, type: :model do
  let(:tienda) { create(:tienda, carrito_de_compras: true) }
  let(:categoria_kiosco) { create(:categoria, nombre: 'Kiosco', tienda: tienda) }
  let(:categoria_bebidas) { create(:categoria, nombre: 'Bebidas', tienda: tienda) }
  let(:categoria_comida) { create(:categoria, nombre: 'Comida', tienda: tienda) }

  describe 'associations' do
    it { is_expected.to have_many(:clientes_turnos_entrega).dependent(:destroy) }
    it { is_expected.to have_many(:clientes).through(:clientes_turnos_entrega) }
    it { is_expected.to have_many(:turnos_entrega_categorias).dependent(:destroy) }
    it { is_expected.to have_many(:categorias_permitidas).through(:turnos_entrega_categorias) }
    it { is_expected.to have_many(:pedidos).dependent(:nullify) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:nombre) }
    it { is_expected.to validate_presence_of(:codigo) }
    it { is_expected.to validate_presence_of(:hora_corte) }
    it { is_expected.to validate_presence_of(:posicion) }

    it 'validates uniqueness of codigo (case insensitive)' do
      create(:turno_entrega, codigo: 'test')
      expect(subject).to validate_uniqueness_of(:codigo).case_insensitive
    end
  end

  describe 'scopes' do
    let!(:turno_activo) { create(:turno_entrega, activo: true) }
    let!(:turno_inactivo) { create(:turno_entrega, activo: false) }

    describe '.activos' do
      it 'returns only active turnos' do
        expect(described_class.activos).to include(turno_activo)
        expect(described_class.activos).not_to include(turno_inactivo)
      end
    end

    describe '.ordenados' do
      let!(:turno_pos_10) { create(:turno_entrega, posicion: 10) }
      let!(:turno_pos_30) { create(:turno_entrega, posicion: 30) }
      let!(:turno_pos_20) { create(:turno_entrega, posicion: 20) }

      it 'returns turnos ordered by posicion' do
        turnos = described_class.ordenados.where(id: [turno_pos_10.id, turno_pos_30.id, turno_pos_20.id])
        expect(turnos.pluck(:posicion)).to eq([10, 20, 30])
      end
    end
  end

  describe '.por_codigo' do
    let!(:turno) { create(:turno_entrega, codigo: 'almuerzo') }

    it 'finds turno by codigo' do
      expect(described_class.por_codigo('almuerzo')).to eq(turno)
    end

    it 'returns nil for non-existent codigo' do
      expect(described_class.por_codigo('inexistente')).to be_nil
    end
  end

  describe '#permite_todas_categorias?' do
    context 'when turno has no categoria restrictions' do
      let(:turno) { create(:turno_entrega) }

      it 'returns true' do
        expect(turno.permite_todas_categorias?).to be true
      end
    end

    context 'when turno has categoria restrictions' do
      let(:turno) { create(:turno_entrega) }

      before do
        create(:turno_entrega_categoria, turno_entrega: turno, categoria: categoria_kiosco)
      end

      it 'returns false' do
        expect(turno.permite_todas_categorias?).to be false
      end
    end
  end

  describe '#permite_categoria?' do
    let(:turno) { create(:turno_entrega) }

    context 'when turno permits all categories' do
      it 'returns true for any category' do
        expect(turno.permite_categoria?(categoria_comida.id)).to be true
      end
    end

    context 'when turno has specific categoria restrictions' do
      before do
        create(:turno_entrega_categoria, turno_entrega: turno, categoria: categoria_kiosco)
        create(:turno_entrega_categoria, turno_entrega: turno, categoria: categoria_bebidas)
      end

      it 'returns true for allowed categories' do
        expect(turno.permite_categoria?(categoria_kiosco.id)).to be true
        expect(turno.permite_categoria?(categoria_bebidas.id)).to be true
      end

      it 'returns false for restricted categories' do
        expect(turno.permite_categoria?(categoria_comida.id)).to be false
      end
    end
  end

  describe '#categorias_disponibles_para_tienda' do
    let(:turno) { create(:turno_entrega) }

    context 'when turno permits all categories' do
      it 'returns all active categories for tienda' do
        categorias = turno.categorias_disponibles_para_tienda(tienda.id)
        expect(categorias).to include(categoria_kiosco, categoria_bebidas, categoria_comida)
      end
    end

    context 'when turno has specific restrictions' do
      before do
        create(:turno_entrega_categoria, turno_entrega: turno, categoria: categoria_kiosco)
        create(:turno_entrega_categoria, turno_entrega: turno, categoria: categoria_bebidas)
      end

      it 'returns only permitted categories' do
        categorias = turno.categorias_disponibles_para_tienda(tienda.id)
        expect(categorias).to include(categoria_kiosco, categoria_bebidas)
        expect(categorias).not_to include(categoria_comida)
      end
    end
  end

  describe '#productos_disponibles_para_tienda' do
    let(:turno) { create(:turno_entrega) }
    let!(:producto_kiosco) { create(:producto, categoria: categoria_kiosco, tienda: tienda) }
    let!(:producto_comida) { create(:producto, categoria: categoria_comida, tienda: tienda) }

    context 'when turno permits all categories' do
      it 'returns all active products for tienda' do
        productos = turno.productos_disponibles_para_tienda(tienda.id)
        expect(productos).to include(producto_kiosco, producto_comida)
      end
    end

    context 'when turno has specific restrictions' do
      before do
        create(:turno_entrega_categoria, turno_entrega: turno, categoria: categoria_kiosco)
      end

      it 'returns only products from permitted categories' do
        productos = turno.productos_disponibles_para_tienda(tienda.id)
        expect(productos).to include(producto_kiosco)
        expect(productos).not_to include(producto_comida)
      end
    end
  end

  describe '#hora_corte_formateada' do
    let(:turno) { create(:turno_entrega, hora_corte: '11:30:00') }

    it 'formats hora_corte as HH:MM' do
      expect(turno.hora_corte_formateada).to eq('11:30')
    end
  end

  describe '#descripcion_completa' do
    let(:turno) { create(:turno_entrega, nombre: 'Almuerzo', hora_corte: '11:00:00', descripcion: 'Todas las categorías') }

    it 'includes nombre, hora_corte, and descripcion' do
      expect(turno.descripcion_completa).to include('Almuerzo')
      expect(turno.descripcion_completa).to include('11:00')
      expect(turno.descripcion_completa).to include('Todas las categorías')
    end

    context 'without descripcion' do
      let(:turno) { create(:turno_entrega, nombre: 'Merienda', hora_corte: '15:00:00', descripcion: nil) }

      it 'includes only nombre and hora_corte' do
        expect(turno.descripcion_completa).to include('Merienda')
        expect(turno.descripcion_completa).to include('15:00')
      end
    end
  end

  describe '#to_s' do
    let(:turno) { create(:turno_entrega, nombre: 'Desayuno') }

    it 'returns nombre' do
      expect(turno.to_s).to eq('Desayuno')
    end
  end
end
