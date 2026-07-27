require 'rails_helper'

RSpec.describe Pedidos::ClienteTurnoEntrega, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:cliente) }
    it { is_expected.to belong_to(:turno_entrega) }
  end

  describe 'validations' do
    let(:cliente) { create(:cliente) }
    let(:turno) { create(:turno_entrega) }

    it 'validates uniqueness of turno_entrega_id scoped to cliente_id' do
      create(:cliente_turno_entrega, cliente: cliente, turno_entrega: turno)
      duplicate = build(:cliente_turno_entrega, cliente: cliente, turno_entrega: turno)

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:turno_entrega_id]).to include('ya existe')
    end

    it 'allows same turno for different clientes' do
      cliente2 = create(:cliente)
      create(:cliente_turno_entrega, cliente: cliente, turno_entrega: turno)
      duplicate = build(:cliente_turno_entrega, cliente: cliente2, turno_entrega: turno)

      expect(duplicate).to be_valid
    end
  end
end
