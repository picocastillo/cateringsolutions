require 'rails_helper'

RSpec.describe Tiendas::Tienda, type: :model do
  describe 'has_and_belongs_to_many :clientes' do
    it 'exposes a clientes association' do
      tienda = create(:tienda)
      expect(tienda).to respond_to(:clientes)
      expect(tienda.clientes).to be_a(ActiveRecord::Relation)
    end

    it 'returns clientes linked via the HABTM' do
      tienda = create(:tienda)
      cliente = create(:cliente, tienda: tienda)
      expect(tienda.clientes).to include(cliente)
    end
  end
end
