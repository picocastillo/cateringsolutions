require 'rails_helper'

# Step 2 of the shared-clientes migration: a Cliente can be linked to multiple Tiendas
# via the new clientes_tiendas join table. The legacy belongs_to :tienda still exists
# (parallel-reads phase), and an after_create callback keeps the HABTM in sync with
# the legacy column.
RSpec.describe Clientes::Cliente, type: :model do
  let(:tienda1) { create(:tienda) }
  let(:tienda2) { create(:tienda) }

  describe 'has_and_belongs_to_many :tiendas' do
    it 'exposes a tiendas association' do
      cliente = create(:cliente, tienda: tienda1)
      expect(cliente).to respond_to(:tiendas)
      expect(cliente.tiendas).to be_a(ActiveRecord::Relation)
    end

    it 'auto-links to the legacy tienda on create (backfill via callback)' do
      cliente = create(:cliente, tienda: tienda1)
      expect(cliente.tiendas).to include(tienda1)
    end

    it 'allows a cliente to be linked to multiple tiendas' do
      cliente = create(:cliente, tienda: tienda1)
      cliente.tiendas << tienda2
      expect(cliente.reload.tiendas).to contain_exactly(tienda1, tienda2)
    end

    it 'is idempotent — re-saving does not duplicate the link' do
      cliente = create(:cliente, tienda: tienda1)
      cliente.save!
      expect(cliente.tiendas.where(id: tienda1.id).count).to eq 1
    end
  end

  describe '#multi_tienda?' do
    it 'returns false when linked to one tienda' do
      cliente = create(:cliente, tienda: tienda1)
      expect(cliente.multi_tienda?).to be false
    end

    it 'returns true when linked to more than one tienda' do
      cliente = create(:cliente, tienda: tienda1)
      cliente.tiendas << tienda2
      expect(cliente.reload.multi_tienda?).to be true
    end
  end

  describe '#disponible_en?' do
    it 'returns true when linked to the given tienda' do
      cliente = create(:cliente, tienda: tienda1)
      expect(cliente.disponible_en?(tienda1)).to be true
    end

    it 'returns false when not linked' do
      cliente = create(:cliente, tienda: tienda1)
      expect(cliente.disponible_en?(tienda2)).to be false
    end
  end
end
