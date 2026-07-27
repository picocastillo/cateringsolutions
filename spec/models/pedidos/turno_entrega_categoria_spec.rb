require 'rails_helper'

RSpec.describe Pedidos::TurnoEntregaCategoria, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:turno_entrega) }
    it { is_expected.to belong_to(:categoria) }
  end

  describe 'validations' do
    let(:turno) { create(:turno_entrega) }
    let(:categoria) { create(:categoria) }

    it 'validates uniqueness of categoria_id scoped to turno_entrega_id' do
      create(:turno_entrega_categoria, turno_entrega: turno, categoria: categoria)
      duplicate = build(:turno_entrega_categoria, turno_entrega: turno, categoria: categoria)

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:categoria_id]).to include('ya existe')
    end

    it 'allows same categoria for different turnos' do
      turno2 = create(:turno_entrega, codigo: 'otro_turno')
      create(:turno_entrega_categoria, turno_entrega: turno, categoria: categoria)
      different = build(:turno_entrega_categoria, turno_entrega: turno2, categoria: categoria)

      expect(different).to be_valid
    end
  end
end
