require 'rails_helper'

RSpec.describe Contabilidad::Imputable do
  describe 'concern inclusion' do
    it 'defines contabilizar method' do
      expect(Cobros::Recibo.new).to respond_to(:contabilizar)
    end

    it 'defines movimientos association' do
      expect(Cobros::Recibo.reflect_on_association(:movimientos)).to be_present
    end
  end
end
