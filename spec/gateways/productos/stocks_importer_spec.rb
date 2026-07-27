require 'rails_helper'
require 'spreadsheet'

RSpec.describe Productos::StocksImporter, type: :gateway do
  let(:tienda) { create(:tienda, nombre: 'Tienda Principal') }
  let(:usuario) { create(:usuario, visualizando_tienda: tienda) }
  let(:producto1) { create(:producto, nombre: 'Producto Alfa', codigo: 'ALFA001', tienda: tienda) }
  let(:producto2) { create(:producto, nombre: 'Producto Beta', codigo: 'BETA002', tienda: tienda) }
  let(:local) { create(:local, tienda: tienda, nombre: 'Local Norte') }

  # Use stock created by producto callback
  let!(:stock_existente) { producto1.stocks.first.tap { |s| s.update!(cantidad_actual: 20, cantidad_minima: 10) } }

  let(:importer) do
    described_class.new(
      params: {},
      autor: usuario
    )
  end

  describe '#process_row' do
    context 'updating existing stock by ID' do
      it 'updates stock quantities using ajustar_stock' do
        row = {
          'ID' => stock_existente.id,
          'Cantidad Actual' => 50,
          'Cantidad Mínima' => 15,
          'Cantidad Máxima' => 100,
          'Activo' => 'Si'
        }

        expect do
          importer.process_row(row)
        end.to change { stock_existente.reload.cantidad_actual }.from(20).to(50)

        expect(stock_existente.cantidad_minima).to eq(15)
        expect(stock_existente.cantidad_maxima).to eq(100)
      end

      it 'creates a stock movement when quantity changes' do
        row = {
          'ID' => stock_existente.id,
          'Cantidad Actual' => 35
        }

        expect do
          importer.process_row(row)
        end.to change(Productos::StockMovimiento, :count).by(1)

        movement = Productos::StockMovimiento.last
        expect(movement.stock_id).to eq(stock_existente.id)
        expect(movement.cantidad_anterior).to eq(20)
        expect(movement.cantidad_nueva).to eq(35)
        expect(movement.motivo).to include('Importación Excel')
      end

      it 'handles activo field correctly' do
        row = {
          'ID' => stock_existente.id,
          'Activo' => 'No'
        }

        importer.process_row(row)
        expect(stock_existente.reload.activo).to be false
      end
    end

    context 'creating new stock by product and tienda' do
      before do
        producto2 # Ensure producto2 is created
        # Delete auto-created stocks to test creation
        producto2.stocks.destroy_all
      end

      it 'creates new stock with producto by code' do
        row = {
          'Producto' => 'Producto Beta',
          'Código' => 'BETA002',
          'Cantidad Actual' => 30,
          'Cantidad Mínima' => 5,
          'Cantidad Máxima' => 50,
          'Activo' => 'Si'
        }

        expect do
          importer.process_row(row)
        end.to change(Productos::Stock, :count).by(1)

        stock = Productos::Stock.last
        expect(stock.producto).to eq(producto2)
        expect(stock.tienda).to eq(tienda)
        expect(stock.local).to be_nil
        expect(stock.cantidad_actual).to eq(30)
        expect(stock.cantidad_minima).to eq(5)
        expect(stock.cantidad_maxima).to eq(50)
        expect(stock.activo).to be true
      end

      it 'creates new stock in main location' do
        producto3 = create(:producto, nombre: 'Producto Gamma', codigo: 'GAMMA003', tienda: tienda)
        # Delete auto-created stocks to test creation
        producto3.stocks.destroy_all

        row = {
          'Producto' => 'Producto Gamma',
          'Código' => 'GAMMA003',
          'Cantidad Actual' => 15,
          'Cantidad Mínima' => 3
        }

        expect do
          importer.process_row(row)
        end.to change(Productos::Stock, :count).by(1)

        stock = Productos::Stock.last
        expect(stock.producto).to eq(producto3)
        expect(stock.local).to be_nil
        expect(stock.cantidad_actual).to eq(15)
      end

      it 'sets default values for new stock' do
        producto2 # Ensure producto2 exists

        row = {
          'Producto' => 'Producto Beta'
        }

        importer.process_row(row)

        stock = Productos::Stock.last
        expect(stock.cantidad_actual).to eq(0)
        expect(stock.cantidad_minima).to eq(0)
        expect(stock.activo).to be true
      end
    end

    context 'error handling' do
      it 'raises error when producto is not found' do
        row = {
          'Producto' => 'Producto Inexistente',
          'Código' => 'NOEXISTE',
          'Tienda' => 'Principal'
        }

        expect do
          importer.process_row(row)
        end.to raise_error(ErrorAplicacion, /No se encontró el producto/)
      end

      it 'raises error when user has no active tienda' do
        allow(usuario).to receive(:tienda_activa).and_return(nil)

        row = {
          'Producto' => 'Producto Alfa'
        }

        expect do
          importer.process_row(row)
        end.to raise_error(ErrorAplicacion, /No se puede determinar la tienda activa/)
      end

      it 'raises error when producto does not belong to tienda' do
        other_tienda = create(:tienda, nombre: 'Otra Tienda')
        create(:producto, nombre: 'Otro Producto', codigo: 'OTRO001', tienda: other_tienda)

        row = {
          'Código' => 'OTRO001'
        }

        # Product search is scoped to user's tienda, so foreign product is not found
        expect do
          importer.process_row(row)
        end.to raise_error(ErrorAplicacion, /No se encontró el producto/)
      end

      it 'raises error when required fields are missing' do
        row = {}

        expect do
          importer.process_row(row)
        end.to raise_error(ErrorAplicacion, /Producto es requerido/)
      end
    end

    context 'find_producto logic' do
      it 'finds producto by exact code' do
        row = {
          'Código' => 'ALFA001',
          'Cantidad Actual' => 10
        }

        importer.process_row(row)

        stock = Productos::Stock.last
        expect(stock.producto).to eq(producto1)
      end

      it 'finds producto by partial name match' do
        row = {
          'Producto' => 'Alfa',
          'Cantidad Actual' => 10
        }

        importer.process_row(row)

        stock = Productos::Stock.last
        expect(stock.producto).to eq(producto1)
      end

      it 'prioritizes code over name when both present' do
        row = {
          'Producto' => 'Wrong Name',
          'Código' => 'ALFA001',
          'Cantidad Actual' => 10
        }

        importer.process_row(row)

        stock = Productos::Stock.last
        expect(stock.producto).to eq(producto1)
      end
    end

    context 'updating vs creating' do
      it 'updates existing stock when producto and tienda match' do
        existing = stock_existente

        row = {
          'Producto' => 'Producto Alfa',
          'Cantidad Actual' => 25
        }

        expect do
          importer.process_row(row)
        end.not_to(change(Productos::Stock, :count))

        expect(existing.reload.cantidad_actual).to eq(25)
      end
    end

    context 'handling cantidad_maxima' do
      it 'sets cantidad_maxima when present' do
        producto2 # Ensure producto2 exists

        row = {
          'Producto' => 'Producto Beta',
          'Cantidad Máxima' => 75
        }

        importer.process_row(row)

        stock = Productos::Stock.last
        expect(stock.cantidad_maxima).to eq(75)
      end

      it 'leaves cantidad_maxima unchanged when empty' do
        stock_existente.update!(cantidad_maxima: 100)

        row = {
          'ID' => stock_existente.id,
          'Cantidad Máxima' => ''
        }

        importer.process_row(row)

        # Empty value should leave it unchanged
        expect(stock_existente.reload.cantidad_maxima).to eq(100)
      end
    end
  end

  describe 'integration with ExcelImporter' do
    it 'processes row data correctly' do
      producto2 # Ensure producto2 exists
      # Delete auto-created stocks to test creation
      producto2.stocks.destroy_all

      # Simulate a row from Excel
      row_data = {
        'ID' => '',
        'Producto' => 'Producto Beta',
        'Código' => 'BETA002',
        'Cantidad Actual' => 40,
        'Cantidad Mínima' => 8,
        'Cantidad Máxima' => 80,
        'Activo' => 'Si'
      }

      expect do
        importer.process_row(row_data)
      end.to change(Productos::Stock, :count).by(1)

      stock = Productos::Stock.last
      expect(stock.producto).to eq(producto2)
      expect(stock.cantidad_actual).to eq(40)
      expect(stock.cantidad_minima).to eq(8)
      expect(stock.cantidad_maxima).to eq(80)
    end
  end

  describe 'local_id behavior' do
    it 'always creates stock with nil local_id (main stock)' do
      producto2.stocks.destroy_all

      row_data = {
        'Producto' => 'Producto Beta',
        'Cantidad Actual' => 25,
        'Cantidad Mínima' => 5
      }

      importer.process_row(row_data)

      stock = Productos::Stock.last
      expect(stock.local_id).to be_nil
      expect(stock.producto).to eq(producto2)
    end

    it 'does not affect local-specific stocks when importing' do
      # Create a local-specific stock
      local_stock = Productos::Stock.create!(
        producto: producto1, tienda: tienda, local: local,
        cantidad_actual: 30, cantidad_minima: 5
      )

      # Import main stock update
      row_data = {
        'ID' => stock_existente.id,
        'Cantidad Actual' => 99
      }

      importer.process_row(row_data)

      local_stock.reload
      expect(local_stock.cantidad_actual).to eq(30) # unchanged
      expect(stock_existente.reload.cantidad_actual).to eq(99)
    end
  end
end
