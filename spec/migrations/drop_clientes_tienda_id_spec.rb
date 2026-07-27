require 'rails_helper'

# Step 8 of clientes-shared migration: drop the legacy `clientes.tienda_id`
# column (replaced by the `clientes_tiendas` HABTM in Step 2) and add the
# unique index on `cuentas.nro` that became safe once Step 7 renumbered all
# cuentas through the global generator.
RSpec.describe 'Step 8: drop clientes.tienda_id + unique cuentas.nro' do
  it 'no longer exposes the tienda_id column on clientes' do
    expect(Clientes::Cliente.column_names).not_to include('tienda_id')
  end

  it 'enforces a unique index on cuentas.nro' do
    indexes = ActiveRecord::Base.connection.indexes('cuentas')
    nro_idx = indexes.find { |i| i.columns == ['nro'] }

    expect(nro_idx).not_to be_nil, 'expected an index on cuentas.nro'
    expect(nro_idx.unique).to be true
  end

  it 'still resolves cliente.tienda via the HABTM (legacy compat)' do
    tienda = create(:tienda)
    cliente = create(:cliente, tiendas: [tienda])

    expect(cliente.tienda).to eq(tienda)
  end

  it 'rejects duplicate cuenta.nro at the database level' do
    cuenta = create(:cliente, :with_cuenta).cuentas.first

    duplicate = build(:cuenta, cliente: create(:cliente))
    duplicate.nro = cuenta.nro

    expect { duplicate.save(validate: false) }
      .to raise_error(ActiveRecord::RecordNotUnique)
  end
end
