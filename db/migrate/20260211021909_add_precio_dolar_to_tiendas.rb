class AddPrecioDolarToTiendas < ActiveRecord::Migration[5.2]
  def change
    add_column :tiendas, :precio_dolar, :float

    reversible do |dir|
      dir.up do
        Rake::Task['cotizacion:actualizar_dolar'].invoke rescue Rails.logger.warn('No se pudo actualizar cotización del dólar durante migración')
      end
    end
  end
end
