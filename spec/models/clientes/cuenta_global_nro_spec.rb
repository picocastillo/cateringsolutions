require 'rails_helper'

# Step 4 + Step 7 of the shared-clientes migration: Cuenta.nro must be
# assigned from a single GLOBAL generator scope ("cuentas_globales") instead
# of the previous per-tienda scope ("tienda#{id}_cuentas_contables"). The
# scope was bumped from 'cuentas_contables' to 'cuentas_globales' as part of
# the one-shot renumber so the counter starts fresh and existing rows were
# reissued in id-asc order (see 20260425_renumber_cuentas_globally).
RSpec.describe Clientes::Cuenta, type: :model do
  describe '#asignar_nro (global generator)' do
    let(:tienda_a) { create(:tienda) }
    let(:tienda_b) { create(:tienda) }
    let(:cliente_a) { create(:cliente, tienda: tienda_a) }
    let(:cliente_b) { create(:cliente, tienda: tienda_b) }

    it 'assigns sequential nros across different tiendas (no per-tienda reset)' do
      cliente_a # force creation (auto-creates initial cuenta)
      cliente_b
      first  = create(:cuenta, cliente: cliente_a)
      second = create(:cuenta, cliente: cliente_b)

      expect(second.nro).to eq(first.nro + 1)
    end

    it 'pulls the next value from the "cuentas_globales" global scope' do
      cliente_a # ensure auto-cuenta has already happened
      starting = Infraestructura::GeneradorSecuencial
                 .where(scope: 'cuentas_globales').first&.ultimo.to_i
      cuenta = create(:cuenta, cliente: cliente_a)
      expect(cuenta.nro).to eq(starting + 1)
    end

    it 'never advances the legacy per-tienda generator scopes' do
      legacy_scope = "tienda#{tienda_a.id}_cuentas_contables"
      before = Infraestructura::GeneradorSecuencial.where(scope: legacy_scope).first&.ultimo.to_i
      create(:cuenta, cliente: cliente_a)
      after = Infraestructura::GeneradorSecuencial.where(scope: legacy_scope).first&.ultimo.to_i
      expect(after).to eq(before)
    end

    it 'still works when the cliente has no tienda (shared cliente, post-migration)' do
      # Step 8 dropped clientes.tienda_id, so a cliente with no tiendas attached
      # represents the post-migration shared/orphaned state.
      cliente = create(:cliente, tiendas: [])
      cuenta = build(:cuenta, cliente: cliente)
      expect { cuenta.save! }.not_to raise_error
      expect(cuenta.nro).to be_present
    end

    it 'does not overwrite an explicitly provided nro' do
      cuenta = build(:cuenta, cliente: cliente_a, nro: 99_999)
      cuenta.save!
      expect(cuenta.nro).to eq 99_999
    end
  end
end
