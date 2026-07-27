require 'rails_helper'

RSpec.describe Productos::Stock, type: :model do
  let(:tienda) { create(:tienda) }
  let(:producto) { create(:producto, tienda: tienda) }
  let(:stock) { create(:stock, producto: producto, tienda: tienda) }

  describe 'associations' do
    it { is_expected.to belong_to(:producto).class_name('Productos::Producto') }
    it { is_expected.to belong_to(:tienda).class_name('Tiendas::Tienda') }
    it { is_expected.to belong_to(:local).class_name('Locales::Local').optional }
  end

  describe 'validations' do
    it { is_expected.to validate_numericality_of(:cantidad_actual).is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_numericality_of(:cantidad_minima).is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_numericality_of(:cantidad_maxima).is_greater_than(0).allow_nil }

    describe 'uniqueness' do
      subject { producto.stocks.first }

      it { is_expected.to validate_uniqueness_of(:producto_id).scoped_to([:tienda_id, :local_id]) }
    end

    context 'cantidad_maxima_mayor_que_minima' do
      it 'is invalid when cantidad_maxima is less than or equal to cantidad_minima' do
        stock = build(:stock, cantidad_minima: 10, cantidad_maxima: 5)
        expect(stock).to be_invalid
        expect(stock.errors[:cantidad_maxima]).to include('debe ser mayor que la cantidad mínima')
      end

      it 'is valid when cantidad_maxima is greater than cantidad_minima' do
        stock = build(:stock, cantidad_minima: 10, cantidad_maxima: 20)
        expect(stock).to be_valid
      end
    end

    context 'producto_pertenece_a_tienda' do
      it 'is invalid when producto belongs to different tienda' do
        other_tienda = create(:tienda)
        other_producto = create(:producto, tienda: other_tienda)
        stock = build(:stock, producto: other_producto, tienda: tienda)

        expect(stock).to be_invalid
        expect(stock.errors[:producto]).to include('debe pertenecer a la misma tienda')
      end
    end
  end

  describe 'scopes' do
    let!(:stock_con_stock) { create(:stock, cantidad_actual: 10) }
    let!(:stock_sin_stock) { create(:stock, cantidad_actual: 0) }
    let!(:stock_bajo) { create(:stock, cantidad_actual: 2, cantidad_minima: 5) }
    let!(:stock_critico) { create(:stock, cantidad_actual: 1, cantidad_minima: 5) }

    it '.con_stock returns stocks with quantity > 0' do
      expect(described_class.con_stock).to include(stock_con_stock)
      expect(described_class.con_stock).not_to include(stock_sin_stock)
    end

    it '.sin_stock returns stocks with quantity = 0' do
      expect(described_class.sin_stock).to include(stock_sin_stock)
      expect(described_class.sin_stock).not_to include(stock_con_stock)
    end

    it '.stock_bajo returns stocks with low stock' do
      expect(described_class.stock_bajo).to include(stock_bajo)
      expect(described_class.stock_bajo).not_to include(stock_con_stock)
    end

    it '.stock_critico returns stocks with critical stock' do
      expect(described_class.stock_critico).to include(stock_critico)
      expect(described_class.stock_critico).not_to include(stock_con_stock)
    end
  end

  describe 'status methods' do
    context 'when stock has quantity' do
      let(:stock) { create(:stock, cantidad_actual: 10, cantidad_minima: 5) }

      it '#disponible? returns true' do
        expect(stock.disponible?).to be true
      end

      it '#stock_bajo? returns false' do
        expect(stock.stock_bajo?).to be false
      end

      it '#stock_critico? returns false' do
        expect(stock.stock_critico?).to be false
      end
    end

    context 'when stock is low' do
      let(:stock) { create(:stock, cantidad_actual: 3, cantidad_minima: 5) }

      it '#stock_bajo? returns true' do
        expect(stock.stock_bajo?).to be true
      end

      it '#stock_critico? returns false' do
        expect(stock.stock_critico?).to be false
      end
    end

    context 'when stock is critical' do
      let(:stock) { create(:stock, cantidad_actual: 1, cantidad_minima: 5) }

      it '#stock_critico? returns true' do
        expect(stock.stock_critico?).to be true
      end
    end

    it '#stock_suficiente? validates required quantity' do
      stock = create(:stock, cantidad_actual: 10)
      expect(stock.stock_suficiente?(5)).to be true
      expect(stock.stock_suficiente?(15)).to be false
    end

    it '#porcentaje_stock calculates percentage correctly' do
      stock = create(:stock, cantidad_actual: 25, cantidad_maxima: 100)
      expect(stock.porcentaje_stock).to eq(25.0)
    end
  end

  describe 'sales forecast and coverage methods' do
    let(:tienda) { create(:tienda) }
    let(:producto) { create(:producto, tienda: tienda) }
    let(:stock) { producto.stocks.first.tap { |s| s.update!(cantidad_actual: 100, cantidad_minima: 10, cantidad_maxima: 200) } }
    let(:cliente) { create(:cliente, tienda: tienda) }
    let(:cuenta) { create(:cuenta, cliente: cliente) }

    describe '#promedio_venta_diaria_90_dias' do
      context 'when there are no sales' do
        it 'returns 0' do
          expect(stock.promedio_venta_diaria_90_dias).to eq(0.0)
        end
      end

      context 'when there are recent sales' do
        before do
          # Ensure stock is loaded and has the correct producto_id
          stock # Force stock to be created

          # Create pedidos with productos_solicitados
          usuario = create(:usuario, visualizando_tienda: tienda)
          usuario.tiendas << tienda unless usuario.tiendas.include?(tienda)

          5.times do |i|
            pedido = build(:pedido, tienda: tienda, cuenta: cuenta,
                                    fecha: (i * 7).days.ago.to_date, estado_id: 3,
                                    autor: usuario, usuario: usuario)
            pedido.save(validate: false)

            # Use stock.producto to ensure we're creating for the right producto
            create(:producto_solicitado, pedido: pedido, producto: stock.producto,
                                         cantidad: 10, precio_unitario: 100)
          end

          # Clear Rails cache to ensure fresh calculation
          Rails.cache.clear
        end

        it 'calculates average daily sales excluding weekends' do
          promedio = stock.promedio_venta_diaria_90_dias
          expect(promedio).to be > 0
          expect(promedio).to be_a(Numeric)
        end

        it 'memoizes the result via Rails.cache' do
          first_call = stock.promedio_venta_diaria_90_dias

          # Second call should use cached value
          second_call = stock.promedio_venta_diaria_90_dias
          expect(second_call).to eq(first_call)
        end
      end

      context 'when comparing with same month previous year' do
        before do
          usuario = create(:usuario, visualizando_tienda: tienda)
          usuario.tiendas << tienda unless usuario.tiendas.include?(tienda)

          # Create recent sales (low volume)
          2.times do |i|
            pedido = build(:pedido, tienda: tienda, cuenta: cuenta,
                                    fecha: (i * 7).days.ago.to_date, estado_id: 3,
                                    autor: usuario, usuario: usuario)
            pedido.save(validate: false)

            create(:producto_solicitado, pedido: pedido, producto: producto,
                                         cantidad: 5, precio_unitario: 100)
          end

          # Create same month last year sales (high volume)
          current_month_last_year = Date.current - 1.year
          3.times do |i|
            pedido = build(:pedido, tienda: tienda, cuenta: cuenta,
                                    fecha: current_month_last_year.beginning_of_month + i.days,
                                    estado_id: 3,
                                    autor: usuario, usuario: usuario)
            pedido.save(validate: false)

            create(:producto_solicitado, pedido: pedido, producto: producto,
                                         cantidad: 50, precio_unitario: 100)
          end
        end

        it 'returns the maximum between 90-day average and same month previous year' do
          promedio = stock.promedio_venta_diaria_90_dias
          # Should favor the higher value from last year's same month
          expect(promedio).to be > 0
        end
      end

      context 'when only pedidos with estado confirmado or higher are counted' do
        before do
          usuario = create(:usuario, visualizando_tienda: tienda)
          usuario.tiendas << tienda unless usuario.tiendas.include?(tienda)

          # Create confirmed pedido (estado_id: 3)
          pedido_confirmado = build(:pedido, tienda: tienda, cuenta: cuenta,
                                             fecha: 5.days.ago.to_date, estado_id: 3,
                                             autor: usuario, usuario: usuario)
          pedido_confirmado.save(validate: false)
          create(:producto_solicitado, pedido: pedido_confirmado, producto: producto,
                                       cantidad: 10, precio_unitario: 100)

          # Create pending pedido (estado_id: 1) - should NOT be counted
          pedido_pendiente = build(:pedido, tienda: tienda, cuenta: cuenta,
                                            fecha: 3.days.ago.to_date, estado_id: 1,
                                            autor: usuario, usuario: usuario)
          pedido_pendiente.save(validate: false)
          create(:producto_solicitado, pedido: pedido_pendiente, producto: producto,
                                       cantidad: 100, precio_unitario: 100)
        end

        it 'only counts confirmed pedidos (estado >= 3)' do
          promedio = stock.promedio_venta_diaria_90_dias
          # The average should be based on the 10 units from confirmed pedido, not the 100 from pending
          expect(promedio).to be < 2 # Much lower than if pending was counted
        end
      end
    end

    describe '#cobertura_estimada_dias' do
      context 'when promedio is zero' do
        before do
          allow(stock).to receive(:promedio_venta_diaria_90_dias).and_return(0)
        end

        it 'returns 0' do
          expect(stock.cobertura_estimada_dias).to eq(0)
        end
      end

      context 'when there is stock and sales history' do
        before do
          allow(stock).to receive(:promedio_venta_diaria_90_dias).and_return(10.0)
          stock.update!(cantidad_actual: 50)
        end

        it 'calculates days of coverage' do
          expect(stock.cobertura_estimada_dias).to eq(5)
        end

        it 'rounds to nearest integer' do
          allow(stock).to receive(:promedio_venta_diaria_90_dias).and_return(7.0)
          stock.update!(cantidad_actual: 50)
          expect(stock.cobertura_estimada_dias).to eq(7) # 50/7 = 7.14 rounds to 7
        end
      end

      context 'when stock is zero' do
        before do
          allow(stock).to receive(:promedio_venta_diaria_90_dias).and_return(10.0)
          stock.update!(cantidad_actual: 0)
        end

        it 'returns 0' do
          expect(stock.cobertura_estimada_dias).to eq(0)
        end
      end
    end

    describe '#minimo_recomendado_45_dias' do
      context 'when promedio is zero' do
        before do
          allow(stock).to receive(:promedio_venta_diaria_90_dias).and_return(0)
        end

        it 'returns minimum of 2' do
          expect(stock.minimo_recomendado_45_dias).to eq(2)
        end
      end

      context 'when promedio results in value less than 2' do
        before do
          allow(stock).to receive(:promedio_venta_diaria_90_dias).and_return(0.02)
        end

        it 'returns minimum of 2' do # = 0.9, rounds to 1
          expect(stock.minimo_recomendado_45_dias).to eq(2)
        end
      end

      context 'when promedio is normal' do
        before do
          allow(stock).to receive(:promedio_venta_diaria_90_dias).and_return(10.5)
        end

        it 'calculates 45 days worth of stock' do
          expect(stock.minimo_recomendado_45_dias).to eq(473) # 45 * 10.5 = 472.5 rounds to 473
        end

        it 'rounds to nearest integer' do
          allow(stock).to receive(:promedio_venta_diaria_90_dias).and_return(5.4)
          expect(stock.minimo_recomendado_45_dias).to eq(243) # 45 * 5.4 = 243
        end
      end

      context 'when promedio would result in exactly 1' do
        before do
          allow(stock).to receive(:promedio_venta_diaria_90_dias).and_return(0.022)
        end

        it 'returns 2 instead of 1' do
          # 45 * 0.022 = 0.99, rounds to 1, but should return 2
          expect(stock.minimo_recomendado_45_dias).to eq(2)
        end
      end
    end
  end

  describe 'stock movement methods' do
    let(:stock) { create(:stock, cantidad_actual: 10) }

    describe '#aumentar_stock' do
      it 'increases stock quantity' do
        expect(stock.aumentar_stock(5)).to be true
        expect(stock.reload.cantidad_actual).to eq(15)
      end

      it 'creates stock movement record' do
        expect do
          stock.aumentar_stock(5, 'reposición')
        end.to change(Productos::StockMovimiento, :count).by(1)
      end

      it 'returns false for invalid quantity' do
        expect(stock.aumentar_stock(-5)).to be false
      end

      it 'assigns usuario to the stock movement when provided' do
        usuario = create(:usuario)
        stock.aumentar_stock(5, 'reposición manual', usuario)
        movimiento = stock.stock_movimientos.last
        expect(movimiento.usuario).to eq(usuario)
      end

      it 'leaves usuario nil when not provided' do
        stock.aumentar_stock(5, 'reposición automática')
        movimiento = stock.stock_movimientos.last
        expect(movimiento.usuario).to be_nil
      end
    end

    describe '#reducir_stock' do
      it 'decreases stock quantity' do
        expect(stock.reducir_stock(3)).to be true
        expect(stock.reload.cantidad_actual).to eq(7)
      end

      it 'creates stock movement record' do
        expect do
          stock.reducir_stock(3, 'venta')
        end.to change(Productos::StockMovimiento, :count).by(1)
      end

      it 'returns false when insufficient stock' do
        expect(stock.reducir_stock(15)).to be false
      end

      it 'returns false for invalid quantity' do
        expect(stock.reducir_stock(-5)).to be false
      end

      it 'assigns usuario to the stock movement when provided' do
        usuario = create(:usuario)
        stock.reducir_stock(3, 'venta manual', usuario)
        movimiento = stock.stock_movimientos.last
        expect(movimiento.usuario).to eq(usuario)
      end
    end

    describe '#ajustar_stock' do
      it 'adjusts stock to new quantity' do
        expect(stock.ajustar_stock(20)).to be true
        expect(stock.reload.cantidad_actual).to eq(20)
      end

      it 'creates movement record for positive adjustment' do
        expect do
          stock.ajustar_stock(15, 'inventario')
        end.to change(Productos::StockMovimiento, :count).by(1)
      end

      it 'creates movement record for negative adjustment' do
        expect do
          stock.ajustar_stock(5, 'inventario')
        end.to change(Productos::StockMovimiento, :count).by(1)
      end

      it 'does not create movement record when no change' do
        expect do
          stock.ajustar_stock(10)
        end.not_to change(Productos::StockMovimiento, :count)
      end

      it 'returns false for negative quantity' do
        expect(stock.ajustar_stock(-5)).to be false
      end

      it 'assigns usuario to the stock movement when provided' do
        usuario = create(:usuario)
        stock.ajustar_stock(20, 'inventario manual', usuario)
        movimiento = stock.stock_movimientos.last
        expect(movimiento.usuario).to eq(usuario)
      end
    end
  end

  describe 'class methods' do
    let(:tienda) { create(:tienda) }
    let!(:producto1) { create(:producto, tienda: tienda) }
    let!(:producto2) { create(:producto, tienda: tienda) }
    let!(:stock1) { producto1.stocks.first.tap { |s| s.update!(cantidad_actual: 0) } }
    let!(:stock2) { producto2.stocks.first.tap { |s| s.update!(cantidad_actual: 5, cantidad_minima: 10) } }

    describe '.productos_sin_stock' do
      it 'returns products without stock' do
        result = described_class.productos_sin_stock(tienda.id)
        expect(result).to include(stock1)
        expect(result).not_to include(stock2)
      end
    end

    describe '.productos_stock_bajo' do
      it 'returns products with low stock' do
        result = described_class.productos_stock_bajo(tienda.id)
        expect(result).to include(stock2)
        expect(result).not_to include(stock1)
      end
    end

    describe '.resumen_stock' do
      it 'returns stock summary' do
        result = described_class.resumen_stock(tienda.id)
        expect(result[:total_productos]).to eq(2)
        expect(result[:sin_stock]).to eq(1)
        expect(result[:stock_bajo]).to eq(1)
      end
    end
  end

  describe 'forecasting improvements' do
    let(:tienda) { create(:tienda) }
    let(:categoria) { create(:categoria, tienda: tienda, stock_activo: true) }
    let(:producto) { create(:producto, tienda: tienda, categoria: categoria) }
    let(:stock) { producto.stocks.first.tap { |s| s.update!(cantidad_actual: 100) } }
    let(:cliente) { create(:cliente, tienda: tienda, horario_corte_pedidos: 1.minute.ago.strftime('%H:%M')) }
    let(:cuenta) { create(:cuenta, cliente: cliente) }
    let(:usuario) do
      u = create(:usuario, cuenta: cuenta, tipo_usuario_id: 1, dni: 12_345_678)
      u.visualizando_tienda = tienda
      u.tiendas << tienda unless u.tiendas.include?(tienda)
      u.save!
      u
    end

    describe '#promedio_venta_diaria_90_dias caching' do
      it 'caches the result for 24 hours' do
        # First call should hit the database
        expect(Rails.cache).to receive(:fetch).with("stock_#{stock.id}_promedio_venta_diaria_90_dias", expires_in: 24.hours).and_call_original
        stock.promedio_venta_diaria_90_dias
      end

      it 'returns cached value on subsequent calls' do
        # Warm up cache
        stock.promedio_venta_diaria_90_dias

        # Clear instance variable to force re-evaluation
        stock.instance_variable_set(:@promedio_venta_diaria_90_dias, nil)

        # Should use cached value
        cached_result = stock.promedio_venta_diaria_90_dias
        expect(cached_result).to be_a(Numeric)
      end
    end

    describe 'excludes cancelled pedidos from forecasts' do
      def create_and_confirm_pedido(fecha_valida)
        pedido = build(:pedido, tienda: tienda, cuenta: cuenta, fecha: fecha_valida,
                                estado_id: 1, autor: usuario, usuario: usuario)
        pedido.asignar_cuenta_manual
        pedido.cuenta = cuenta
        pedido.save!
        allow(pedido).to receive(:crear_comprobante)
        pedido
      end

      it 'only counts confirmado (3) and finalizado (4) pedidos' do
        # Use a valid weekday in the future
        fecha_valida = Date.current + 1
        fecha_valida += 1 while fecha_valida.saturday? || fecha_valida.sunday?

        pedido_confirmado = create_and_confirm_pedido(fecha_valida)
        create(:producto_solicitado, pedido: pedido_confirmado, producto: producto, cantidad: 5, precio_unitario: 100)
        pedido_confirmado.aceptar!
        pedido_confirmado.update_column(:fecha, Date.current)
        pedido_confirmado.confirmar!(usuario)

        pedido_cancelado = create_and_confirm_pedido(fecha_valida)
        create(:producto_solicitado, pedido: pedido_cancelado, producto: producto, cantidad: 10, precio_unitario: 100)
        pedido_cancelado.aceptar!
        pedido_cancelado.update_column(:fecha, Date.current)
        pedido_cancelado.confirmar!(usuario)
        pedido_cancelado.cancelar!

        # Clear cache
        Rails.cache.delete("stock_#{stock.id}_promedio_venta_diaria_90_dias")
        stock.instance_variable_set(:@promedio_venta_diaria_90_dias, nil)

        # Calculate promedio - should only include confirmed pedido (5 units)
        promedio = stock.promedio_venta_diaria_90_dias

        # Should be based on 5 units, not 15 (5 + 10)
        expect(promedio).to be > 0
        expect(promedio).to be < 1 # 5 units / weekdays in 90 days should be small
      end
    end
  end
end
