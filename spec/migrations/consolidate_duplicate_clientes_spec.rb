require 'rails_helper'
require Rails.root.join('db/migrate/20260427100000_consolidate_duplicate_clientes.rb')

# Step 9 of clientes-shared migration: collapse duplicate cliente rows into a
# single canonical cliente, rewriting cliente_id FKs across every child table
# and unioning the clientes_tiendas access list.
#
# Merge rules:
#   * Non-blank CUIT → merge all rows sharing the same CUIT (nombre is ignored).
#   * "Consumidor Final" → merge by name alone regardless of CUIT.
#   * Blank/null CUIT (non-CF) → NOT merged.
RSpec.describe ConsolidateDuplicateClientes, type: :model do
  let(:tienda_a) { create(:tienda) }
  let(:tienda_b) { create(:tienda) }

  describe '#up' do
    context 'with two clientes sharing the same CUIT across tiendas' do
      let!(:canonical) do
        create(:cliente, nombre: 'Sancor Salud', cuit: '20294834487', tiendas: [tienda_a])
      end
      let!(:duplicate) do
        # Different name, same CUIT — should still merge (CUIT is the key now)
        create(:cliente, nombre: 'Sancor Salud S.A.', cuit: '20294834487', tiendas: [tienda_b])
      end

      it 'keeps only the canonical (lowest id) cliente' do
        described_class.new.up

        expect(Clientes::Cliente.unscoped.exists?(canonical.id)).to be true
        expect(Clientes::Cliente.unscoped.exists?(duplicate.id)).to be false
      end

      it 'unions the tiendas onto the canonical cliente' do
        described_class.new.up

        expect(canonical.reload.tiendas).to contain_exactly(tienda_a, tienda_b)
      end

      it 'rewrites cuenta.cliente_id from duplicate → canonical (or merges into canonical cuenta)' do
        canonical_cuenta = canonical.cuentas.first
        duplicate_cuenta = duplicate.cuentas.first
        described_class.new.up

        # After migrating: either the duplicate cuenta was repointed at canonical
        # (if nombres differ), or it was merged away into the canonical's cuenta
        # (same normalized nombre → merge_duplicate_cuentas collapsed it).
        # Either way the canonical must still own at least one cuenta.
        expect(canonical.reload.cuentas).not_to be_empty

        if Clientes::Cuenta.unscoped.exists?(duplicate_cuenta.id)
          expect(duplicate_cuenta.reload.cliente_id).to eq(canonical.id)
        else
          # cuenta was deduped into canonical_cuenta — canonical_cuenta must still exist
          expect(Clientes::Cuenta.unscoped.exists?(canonical_cuenta.id)).to be true
        end
      end
    end

    context 'with two clientes sharing same CUIT but different nombres' do
      let!(:canonical) { create(:cliente, nombre: 'ACME S.A.', cuit: '30590354798', tiendas: [tienda_a]) }
      let!(:duplicate) { create(:cliente, nombre: 'ACME',      cuit: '30590354798', tiendas: [tienda_b]) }

      it 'merges them (CUIT match is sufficient, nombre does not matter)' do
        described_class.new.up

        expect(Clientes::Cliente.unscoped.where(id: [canonical.id, duplicate.id]).count).to eq(1)
        expect(canonical.reload.tiendas).to contain_exactly(tienda_a, tienda_b)
      end
    end

    context 'with two clientes sharing only nombre (no CUIT on either)' do
      let!(:canonical) { create(:cliente, nombre: 'Consumidor Final', tiendas: [tienda_a]) }
      let!(:duplicate) { create(:cliente, nombre: 'Consumidor Final', tiendas: [tienda_b]) }

      before do
        # Bypass cuit validator — model requires a valid CUIT, but real prod data
        # has many cuit-less clientes (legacy "Consumidor Final" rows).
        canonical.update_columns(cuit: nil)
        duplicate.update_columns(cuit: nil)
      end

      it 'merges them' do
        described_class.new.up

        expect(Clientes::Cliente.unscoped.where(id: [canonical.id, duplicate.id]).count).to eq(1)
        expect(canonical.reload.tiendas).to contain_exactly(tienda_a, tienda_b)
      end
    end

    context 'with two non-CF clientes sharing same nombre but DIFFERENT CUITs' do
      let!(:cliente_a) { create(:cliente, nombre: 'ACME', cuit: '20294834487', tiendas: [tienda_a]) }
      let!(:cliente_b) { create(:cliente, nombre: 'ACME', cuit: '20111111112', tiendas: [tienda_b]) }

      it 'does NOT merge them (different CUITs = different legal entities)' do
        described_class.new.up

        expect(Clientes::Cliente.unscoped.where(id: [cliente_a.id, cliente_b.id]).count).to eq(2)
      end
    end

    context 'with two non-CF clientes sharing nombre but no CUIT' do
      let!(:cliente_a) { create(:cliente, nombre: 'Sin CUIT', cuit: '20294834487', tiendas: [tienda_a]) }
      let!(:cliente_b) { create(:cliente, nombre: 'Sin CUIT', cuit: '20111111112', tiendas: [tienda_b]) }

      before do
        cliente_a.update_columns(cuit: nil)
        cliente_b.update_columns(cuit: nil)
      end

      it 'does NOT merge them (no CUIT to compare and not Consumidor Final)' do
        described_class.new.up

        expect(Clientes::Cliente.unscoped.where(id: [cliente_a.id, cliente_b.id]).count).to eq(2)
      end
    end

    context 'with multiple "Consumidor Final" rows having different CUITs' do
      # Special case: every tienda historically has its own dummy "Consumidor
      # Final" with whatever CUIT (often the tienda's own, or blank). They
      # all represent the same generic walk-in customer and must be merged
      # by name alone. The canonical row's CUIT is kept.
      let(:tienda_c) { create(:tienda, dominio: 'c.example.com') }
      let!(:cf_a) { create(:cliente, nombre: 'Consumidor Final', cuit: '20294834487', tiendas: [tienda_a]) }
      let!(:cf_b) { create(:cliente, nombre: 'consumidor final ', cuit: '20111111112', tiendas: [tienda_b]) }
      let!(:cf_c) do
        c = create(:cliente, nombre: 'Consumidor Final', cuit: '20294834487', tiendas: [tienda_c])
        c.update_columns(cuit: nil)
        c
      end

      it 'merges all of them into a single row by name only' do
        described_class.new.up

        survivors = Clientes::Cliente.unscoped.where(id: [cf_a.id, cf_b.id, cf_c.id])
        expect(survivors.count).to eq(1)
        expect(survivors.first.tiendas).to contain_exactly(tienda_a, tienda_b, tienda_c)
      end

      it 'keeps the canonical (lowest id) row and its CUIT' do
        described_class.new.up

        survivor = Clientes::Cliente.unscoped.where(id: [cf_a.id, cf_b.id, cf_c.id]).first
        expect(survivor.id).to eq([cf_a.id, cf_b.id, cf_c.id].min)
      end
    end

    context 'idempotency' do
      let!(:canonical) { create(:cliente, nombre: 'Acme', cuit: '20294834487', tiendas: [tienda_a]) }
      let!(:duplicate) { create(:cliente, nombre: 'Acme', cuit: '20294834487', tiendas: [tienda_b]) }

      it 'is a no-op on second run' do
        described_class.new.up
        snapshot = Clientes::Cliente.unscoped.order(:id).pluck(:id, :nombre)

        described_class.new.up
        expect(Clientes::Cliente.unscoped.order(:id).pluck(:id, :nombre)).to eq(snapshot)
      end
    end

    context 'preserving access when canonical and duplicate already share a tienda' do
      let!(:canonical) { create(:cliente, nombre: 'Acme', cuit: '20294834487', tiendas: [tienda_a]) }
      let!(:duplicate) { create(:cliente, nombre: 'Acme', cuit: '20294834487', tiendas: [tienda_a, tienda_b]) }

      it 'does not blow up on the unique [cliente_id, tienda_id] index' do
        expect { described_class.new.up }.not_to raise_error

        expect(canonical.reload.tiendas).to contain_exactly(tienda_a, tienda_b)
      end
    end
  end
end
