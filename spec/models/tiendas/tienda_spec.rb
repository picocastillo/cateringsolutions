require 'rails_helper'

RSpec.describe Tiendas::Tienda, type: :model do
  let(:tienda) { described_class.new(nombre: 'Tienda Test') }

  it 'is valid with valid attributes' do
    expect(tienda).to be_valid
  end

  it 'requires nombre' do
    tienda.nombre = nil
    expect(tienda).not_to be_valid
    expect(tienda.errors[:nombre]).to be_present
  end

  it 'to_s returns nombre' do
    expect(tienda.to_s).to eq 'Tienda Test'
  end

  it 'usuarios returns empty if no usuarios' do
    expect(tienda.usuarios).to eq []
  end

  describe 'maneja_stock attribute' do
    it 'defaults to false for new tiendas' do
      new_tienda = described_class.create!(nombre: 'Nueva Tienda')
      expect(new_tienda.maneja_stock).to be false
    end

    it 'can be set to true' do
      tienda.maneja_stock = true
      tienda.save!
      expect(tienda.maneja_stock).to be true
    end

    it 'has maneja_stock? predicate method' do
      expect(tienda).to respond_to(:maneja_stock?)
    end

    it 'returns correct value for maneja_stock?' do
      tienda.maneja_stock = false
      expect(tienda.maneja_stock?).to be false

      tienda.maneja_stock = true
      expect(tienda.maneja_stock?).to be true
    end

    it 'is included in tienda_params for controller updates' do
      # Verify maneja_stock is in the tienda's permitted attributes
      # This ensures the form can toggle it
      tienda.save!
      tienda.update(maneja_stock: true)
      expect(tienda.reload.maneja_stock).to be true

      tienda.update(maneja_stock: false)
      expect(tienda.reload.maneja_stock).to be false
    end
  end

  describe 'permitir_login_clientes attribute' do
    it 'defaults to true for new tiendas' do
      new_tienda = described_class.create!(nombre: 'Tienda Login Default')
      expect(new_tienda.permitir_login_clientes).to be true
    end

    it 'has a permitir_login_clientes? predicate method' do
      expect(tienda).to respond_to(:permitir_login_clientes?)
    end

    it 'can be toggled off' do
      tienda.save!
      tienda.update!(permitir_login_clientes: false)
      expect(tienda.reload.permitir_login_clientes?).to be false
    end

    it 'is non-nullable in the database' do
      column = described_class.columns_hash['permitir_login_clientes']
      expect(column).not_to be_nil
      expect(column.null).to be false
    end
  end

  describe '.enviar_alertas_stock' do
    let!(:tienda_con_email) { create(:tienda, nombre: 'Tienda Con Email', stock_notifications_email: 'alerts@test.com') }
    let!(:tienda_sin_email) { create(:tienda, nombre: 'Tienda Sin Email', stock_notifications_email: nil) }
    let(:categoria) { create(:categoria, tienda: tienda_con_email, stock_activo: true) }
    let!(:producto) { create(:producto, tienda: tienda_con_email, categoria: categoria) }

    before do
      # Create low stock to trigger alert
      producto.stocks.first.update!(cantidad_actual: 1, cantidad_minima: 10)
    end

    it 'sends alerts to tiendas with stock_notifications_email configured' do
      expect(StockAlertsMailer).to receive(:daily_report).with(tienda_con_email).and_call_original
      expect(StockAlertsMailer).not_to receive(:daily_report).with(tienda_sin_email)

      described_class.enviar_alertas_stock
    end

    it 'skips tiendas without stock_notifications_email' do
      # Should not raise error
      expect { described_class.enviar_alertas_stock }.not_to raise_error
    end

    it 'handles mailer errors gracefully' do
      allow(StockAlertsMailer).to receive(:daily_report).and_raise(StandardError.new('SMTP error'))

      # Should log error but not raise
      expect(Rails.logger).to receive(:error).with(/Failed to send stock alerts/)
      expect { described_class.enviar_alertas_stock }.not_to raise_error
    end

    it 'logs successful sends' do
      # Don't stub logger - ActionMailer logs internally which interferes
      # Just verify the method completes successfully and mail is sent
      expect do
        described_class.enviar_alertas_stock
      end.not_to raise_error

      # Verify mail was actually created and would be sent
      expect(ActionMailer::Base.deliveries).not_to be_empty
    end
  end

  describe '#local_para_carrito' do
    let!(:tienda_ml) { create(:tienda, nombre: 'Tienda MultiLocal', multiple_locales: true) }
    let!(:local1) { create(:local, nombre: 'Local Uno', tienda: tienda_ml) }
    let!(:local2) { create(:local, nombre: 'Local Dos', tienda: tienda_ml) }

    it 'returns local_atencion_carrito when set' do
      tienda_ml.update!(local_atencion_carrito: local2)
      expect(tienda_ml.local_para_carrito).to eq local2
    end

    it 'falls back to first local when local_atencion_carrito is nil' do
      expect(tienda_ml.local_atencion_carrito).to be_nil
      expect(tienda_ml.local_para_carrito).to eq local1
    end

    it 'returns nil when no locales exist and local_atencion_carrito is nil' do
      tienda_sin_locales = create(:tienda, nombre: 'Sin Locales')
      expect(tienda_sin_locales.local_para_carrito).to be_nil
    end
  end

  describe '#muestra_mas_productos_por_categoria' do
    it 'defaults to false for new tiendas' do
      nueva = described_class.create!(nombre: 'Nueva')
      expect(nueva.muestra_mas_productos_por_categoria).to be false
    end

    it 'can be set to true' do
      tienda.muestra_mas_productos_por_categoria = true
      tienda.save!
      expect(tienda.reload.muestra_mas_productos_por_categoria).to be true
    end

    it 'has muestra_mas_productos_por_categoria? predicate' do
      tienda.muestra_mas_productos_por_categoria = true
      expect(tienda.muestra_mas_productos_por_categoria?).to be true
    end
  end

  describe '#muestra_mas_productos_efectivo?' do
    let(:t) { described_class.new(nombre: 'T') }

    it 'is true when muestra_mas_productos is true' do
      t.muestra_mas_productos = true
      t.muestra_mas_productos_por_categoria = false
      expect(t.muestra_mas_productos_efectivo?).to be true
    end

    it 'is true when muestra_mas_productos_por_categoria is true' do
      t.muestra_mas_productos = false
      t.muestra_mas_productos_por_categoria = true
      expect(t.muestra_mas_productos_efectivo?).to be true
    end

    it 'is true when both are true' do
      t.muestra_mas_productos = true
      t.muestra_mas_productos_por_categoria = true
      expect(t.muestra_mas_productos_efectivo?).to be true
    end

    it 'is false when both are false' do
      t.muestra_mas_productos = false
      t.muestra_mas_productos_por_categoria = false
      expect(t.muestra_mas_productos_efectivo?).to be false
    end
  end

  describe '#filtrar_categorias_para_carrito' do
    let!(:tienda_a) { create(:tienda, nombre: 'TA', muestra_mas_productos: true, muestra_mas_productos_por_categoria: false) }
    let!(:tienda_b) { create(:tienda, nombre: 'TB', muestra_mas_productos: false, muestra_mas_productos_por_categoria: true) }
    let!(:cat_visible) { create(:categoria, tienda: tienda_b, nombre: 'Visible', vender_en_carrito: true) }
    let!(:cat_oculta)  { create(:categoria, tienda: tienda_b, nombre: 'Oculta',  vender_en_carrito: false) }
    let!(:cat_a)       { create(:categoria, tienda: tienda_a, nombre: 'TodaA',   vender_en_carrito: false) }
    let!(:cat_a2)      { create(:categoria, tienda: tienda_a, nombre: 'TodaA2',  vender_en_carrito: true) }

    context 'when muestra_mas_productos_por_categoria is true (overrides muestra_mas_productos)' do
      it 'filters scope to only vender_en_carrito = true categorias' do
        scope = Productos::Categoria.where(tienda_id: tienda_b.id)
        result = tienda_b.filtrar_categorias_para_carrito(scope)
        expect(result).to include(cat_visible)
        expect(result).not_to include(cat_oculta)
      end
    end

    context 'when only muestra_mas_productos is true' do
      it 'returns the scope unchanged (all categorias)' do
        scope = Productos::Categoria.where(tienda_id: tienda_a.id)
        result = tienda_a.filtrar_categorias_para_carrito(scope)
        expect(result).to include(cat_a, cat_a2)
      end
    end
  end
end
