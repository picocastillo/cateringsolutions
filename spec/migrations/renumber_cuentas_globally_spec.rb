require 'rails_helper'
require Rails.root.join('db/migrate/20260425100000_renumber_cuentas_globally.rb')

# Step 7 of shared-clientes migration: verify the one-shot renumber assigns
# globally-unique, sequential Cuenta.nros in id-asc order regardless of tienda.
RSpec.describe RenumberCuentasGlobally, type: :model do
  let(:tienda_a) { create(:tienda) }
  let(:tienda_b) { create(:tienda) }
  let(:cliente_a) { create(:cliente, tienda: tienda_a) }
  let(:cliente_b) { create(:cliente, tienda: tienda_b) }

  before do
    # Build a representative pre-migration state: two tiendas, several cuentas
    # with arbitrary existing nros that the migration must overwrite.
    # (We can't simulate the original cross-tienda nro collisions here because
    # Step 8 added a unique index on cuentas.nro — but that's fine: the
    # migration's contract is to *reissue* every nro from the fresh global
    # generator, regardless of starting values.)
    cliente_a # auto-creates initial cuenta
    cliente_b
    @c1 = create(:cuenta, cliente: cliente_a)
    @c2 = create(:cuenta, cliente: cliente_b)
    @c3 = create(:cuenta, cliente: cliente_a)
  end

  it 'assigns globally unique, strictly increasing nros in id-asc order' do
    described_class.new.up

    cuentas = Clientes::Cuenta.unscoped.order(:id).to_a
    nros = cuentas.map(&:nro)

    expect(nros.uniq.size).to eq(nros.size), "nros must be unique, got duplicates in #{nros.inspect}"
    expect(nros).to eq(nros.sort), 'nros must be strictly increasing in id-asc order'
    expect(nros.first).to eq(1), 'fresh generator scope should start the counter at 1'
  end

  it 'leaves the cuentas_globales generator row at the highest assigned nro' do
    described_class.new.up

    max_nro = Clientes::Cuenta.unscoped.maximum(:nro)
    gen = Infraestructura::GeneradorSecuencial.find_by(scope: 'cuentas_globales')

    expect(gen.ultimo).to eq(max_nro)
  end

  it 'is idempotent — running twice produces the same final set of nros' do
    described_class.new.up
    first_pass = Clientes::Cuenta.unscoped.order(:id).pluck(:id, :nro)

    described_class.new.up
    second_pass = Clientes::Cuenta.unscoped.order(:id).pluck(:id, :nro)

    expect(second_pass).to eq(first_pass)
  end
end
