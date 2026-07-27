class RenumberCuentasGlobally < ActiveRecord::Migration[7.1]
  # Step 7 of the shared-clientes migration: re-issue Cuenta.nro from a single
  # global counter so numbers are unique across all tiendas.
  #
  # Strategy (matches the user-requested approach):
  #   1. The model now uses a fresh generator scope ('cuentas_globales') in
  #      Clientes::Cuenta#asignar_nro, so the counter starts at 1.
  #   2. Walk every cuenta ordered by id ASC, blank its nro, and call the
  #      generator directly via update_columns (skips validations and
  #      timestamps to keep the renumber idempotent and quiet).
  #
  # We also wipe any prior 'cuentas_globales' generator row so the migration
  # is idempotent in case it gets re-run on a half-renumbered db.
  def up
    say_with_time 'Renumbering Clientes::Cuenta globally' do
      Infraestructura::GeneradorSecuencial.where(scope: 'cuentas_globales').delete_all

      total = Clientes::Cuenta.unscoped.count
      reissued = 0

      Clientes::Cuenta.unscoped.order(:id).find_each(batch_size: 500) do |cuenta|
        nuevo_nro = Infraestructura::GeneradorSecuencial.proximo('cuentas_globales')
        cuenta.update_columns(nro: nuevo_nro)
        reissued += 1
      end

      say "reissued #{reissued} of #{total} cuentas", true
      reissued
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration,
          'Cuenta.nro values were rewritten globally; the original per-tienda numbers are not recoverable.'
  end
end
