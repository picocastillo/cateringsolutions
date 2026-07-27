require 'rails_helper'

RSpec.describe Productos::Precio, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:producto).class_name('Productos::Producto') }
    it { is_expected.to have_and_belong_to_many(:clientes).class_name('Clientes::Cliente') }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:producto) }
    it { is_expected.to validate_presence_of(:importe) }
    it { is_expected.to validate_numericality_of(:importe).is_greater_than(0) }

    it 'requires fecha_desde when importe is blank' do
      precio = described_class.new(importe: nil, fecha_desde: nil)
      precio.valid?
      expect(precio.fecha_desde).to be_nil
      expect(precio.errors[:fecha_desde]).to be_present
    end
  end

  describe 'acts_as_discontinued' do
    let(:producto) { create(:producto) }
    let(:precio) { described_class.create!(producto: producto, importe: 100, fecha_desde: Time.zone.today) }

    it 'has discontinued_at column' do
      expect(precio).to respond_to(:discontinued_at)
    end

    it 'can be discontinued' do
      precio.discontinue!
      expect(precio.discontinued?).to be true
    end
  end

  describe 'instance methods' do
    let(:producto) { create(:producto) }
    let(:precio) { described_class.new(producto: producto, importe: 150.50, fecha_desde: Time.zone.today) }

    describe '#vigente?' do
      it 'returns true when date is within range' do
        precio.fecha_desde = Date.new(2024, 1, 1)
        precio.fecha_hasta = Date.new(2024, 12, 31)
        expect(precio.vigente?(Date.new(2024, 6, 15))).to be true
      end

      it 'returns false when date is before fecha_desde' do
        precio.fecha_desde = Date.new(2024, 6, 1)
        precio.fecha_hasta = nil
        expect(precio.vigente?(Date.new(2024, 5, 1))).to be false
      end

      it 'returns false when date is after fecha_hasta' do
        precio.fecha_desde = Date.new(2024, 1, 1)
        precio.fecha_hasta = Date.new(2024, 3, 31)
        expect(precio.vigente?(Date.new(2024, 6, 1))).to be false
      end

      it 'returns true when fecha_hasta is nil and date is after fecha_desde' do
        precio.fecha_desde = Date.new(2024, 1, 1)
        precio.fecha_hasta = nil
        expect(precio.vigente?(Date.new(2024, 6, 15))).to be true
      end

      it 'works with Time.zone.today default' do
        allow(Time.zone).to receive(:today).and_return(Date.new(2024, 6, 15))
        precio.fecha_desde = Date.new(2024, 1, 1)
        precio.fecha_hasta = nil
        expect(precio.vigente?).to be true
      end
    end

    describe '#activo_a?' do
      let(:tienda) { create(:tienda) }
      let(:cliente1) { create(:cliente, tienda: tienda) }
      let(:cliente2) { create(:cliente, tienda: tienda, nombre: 'Cliente 2') }

      it 'returns true when vigente and no clientes assigned' do
        precio.fecha_desde = Date.new(2024, 1, 1)
        precio.fecha_hasta = Date.new(2027, 12, 31)
        precio.save!
        expect(precio.activo_a?([cliente1.id])).to be true
      end

      it 'returns true when vigente and cliente is in the list' do
        precio.fecha_desde = Date.new(2024, 1, 1)
        precio.fecha_hasta = Date.new(2027, 12, 31)
        precio.save!
        precio.clientes << cliente1
        precio.reload
        expect(precio.activo_a?([cliente1.id])).to be true
      end

      it 'returns false when vigente but cliente is not in the list' do
        precio.fecha_desde = Date.new(2024, 1, 1)
        precio.fecha_hasta = Date.new(2027, 12, 31)
        precio.save!
        precio.clientes << cliente1
        precio.reload
        expect(precio.activo_a?([cliente2.id])).to be false
      end

      it 'returns false when not vigente' do
        precio.fecha_desde = Date.new(2022, 1, 1)
        precio.fecha_hasta = Date.new(2022, 12, 31)
        precio.save!
        expect(precio.activo_a?([cliente1.id])).to be false
      end
    end

    describe '#to_s' do
      it 'returns formatted string with producto and price' do
        expect(precio.to_s).to include(producto.to_s)
        expect(precio.to_s).to include('150')
      end
    end

    describe '#nombre_codigos_y_precio' do
      it 'returns HTML formatted string with producto name' do
        result = precio.nombre_codigos_y_precio
        expect(result).to include(producto.to_s)
        expect(result).to include('row')
      end

      it 'includes modificador descripcion when provided' do
        modificador = double('modificador', descripcion: 'Extra Grande')
        result = precio.nombre_codigos_y_precio(modificador)
        expect(result).to include('Extra grande')
      end
    end

    describe '#nombre_corto_y_precio' do
      it 'returns HTML formatted string' do
        result = precio.nombre_corto_y_precio
        expect(result).to include('row')
        expect(result).to include('col-')
      end

      it 'uses modificador descripcion when provided' do
        modificador = double('modificador', descripcion: 'Extra Grande')
        result = precio.nombre_corto_y_precio(modificador)
        expect(result).to include('Extra grande')
      end
    end
  end
end
