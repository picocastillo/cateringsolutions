require 'rails_helper'

RSpec.describe Pedidos::Horario, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:tienda).class_name('Tiendas::Tienda') }
    it { is_expected.to have_many(:pedidos).class_name('Pedidos::Pedido') }
  end

  describe 'acts_as_discontinued' do
    let(:tienda) { create(:tienda) }
    let(:horario) { described_class.create!(tienda: tienda, nombre: 'Horario Test') }

    it 'has discontinued_at column' do
      expect(horario).to respond_to(:discontinued_at)
    end

    it 'can be discontinued' do
      horario.discontinue!
      expect(horario.discontinued?).to be true
    end
  end

  describe 'acts_as_list' do
    let(:tienda) { create(:tienda) }
    let(:horario1) { described_class.create!(tienda: tienda, nombre: 'Horario 1') }
    let(:horario2) { described_class.create!(tienda: tienda, nombre: 'Horario 2') }

    it 'has position column' do
      expect(horario1).to respond_to(:position)
    end

    it 'assigns position within tienda scope' do
      horario1 # create first
      horario2 # create second
      expect(horario2.position).to be > horario1.position
    end
  end

  describe 'callbacks' do
    describe '#rectificar_predeterminado' do
      let(:tienda) { create(:tienda) }
      let!(:horario1) { described_class.create!(tienda: tienda, nombre: 'Horario 1', predeterminado: true) }
      let!(:horario2) { described_class.create!(tienda: tienda, nombre: 'Horario 2', predeterminado: false) }

      it 'unsets predeterminado on other horarios when setting one as predeterminado' do
        horario2.update!(predeterminado: true)

        horario1.reload
        expect(horario1.predeterminado).to be false
        expect(horario2.predeterminado).to be true
      end

      it 'does not affect horarios from other tiendas' do
        otra_tienda = create(:tienda, nombre: 'Otra Tienda')
        horario_otra = described_class.create!(tienda: otra_tienda, nombre: 'Horario Otra', predeterminado: true)

        horario2.update!(predeterminado: true)

        horario_otra.reload
        expect(horario_otra.predeterminado).to be true
      end

      it 'allows multiple horarios with predeterminado false' do
        horario1.update!(predeterminado: false)

        horario1.reload
        horario2.reload
        expect(horario1.predeterminado).to be false
        expect(horario2.predeterminado).to be false
      end
    end
  end

  describe 'instance methods' do
    let(:tienda) { create(:tienda) }
    let(:horario) { described_class.create!(tienda: tienda, nombre: 'Horario Test') }

    describe '#to_s' do
      it 'delegates to nombre' do
        expect(horario.to_s).to eq 'Horario Test'
      end
    end

    describe '#por_defecto=' do
      it 'sets predeterminado to true when given truthy value' do
        horario.por_defecto = true
        expect(horario.predeterminado).to be true
      end

      it 'sets predeterminado to true when given string "true"' do
        horario.por_defecto = 'true'
        expect(horario.predeterminado).to be true
      end

      it 'sets predeterminado to false when given falsy value' do
        horario.por_defecto = false
        expect(horario.predeterminado).to be false
      end

      it 'sets predeterminado to false when given string "false"' do
        horario.por_defecto = 'false'
        expect(horario.predeterminado).to be false
      end
    end

    describe '#por_defecto' do
      it 'returns predeterminado value' do
        horario.predeterminado = true
        expect(horario.por_defecto).to be true

        horario.predeterminado = false
        expect(horario.por_defecto).to be false
      end
    end
  end
end
