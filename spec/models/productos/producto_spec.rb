require 'rails_helper'

RSpec.describe Productos::Producto, type: :model do
  let(:tienda) { Tiendas::Tienda.create!(nombre: 'Tienda Producto') }
  let(:categoria) { Productos::Categoria.create!(nombre: 'Categoria Test', tienda: tienda, stock_activo: true) }
  let(:producto) { described_class.new(nombre: 'Producto Test', categoria: categoria, tienda: tienda) }

  describe 'validations' do
    it 'is valid with valid attributes' do
      expect(producto).to be_valid
    end

    it 'requires nombre' do
      producto.nombre = nil
      expect(producto).not_to be_valid
      expect(producto.errors[:nombre]).to be_present
    end
  end

  describe 'associations' do
    it { is_expected.to have_many(:stocks).dependent(:destroy).class_name('Productos::Stock') }
    it { is_expected.to have_many(:stock_movimientos).through(:stocks).class_name('Productos::StockMovimiento') }

    it 'categoria returns assigned categoria' do
      expect(producto.categoria).to eq categoria
    end

    it 'tienda returns assigned tienda' do
      expect(producto.tienda).to eq tienda
    end
  end

  describe 'callbacks' do
    it 'creates initial stock after creation' do
      expect do
        producto.save!
      end.to change(Productos::Stock, :count).by(1)
    end

    context 'when tienda has multiple locales' do
      let(:tienda) { create(:tienda, multiple_locales: true) }
      let!(:local1) { create(:local, tienda: tienda) }
      let!(:local2) { create(:local, tienda: tienda) }

      it 'creates stock for each local' do
        allow(tienda).to receive_messages(multiple_locales?: true, locales: [local1, local2])

        # principal + 2 locales
        expect do
          producto.save!
        end.to change(Productos::Stock, :count).by(3)
      end
    end
  end

  describe 'stock management methods' do
    let!(:producto) { create(:producto, tienda: tienda) }
    let!(:stock) { producto.stocks.first.tap { |s| s.update!(cantidad_actual: 20) } }

    describe '#stock_actual' do
      it 'returns current stock quantity' do
        expect(producto.stock_actual).to eq(20)
      end

      it 'returns 0 when no stock exists' do
        other_producto = create(:producto, tienda: tienda)
        other_producto.stocks.destroy_all
        expect(other_producto.stock_actual).to eq(0)
      end
    end

    describe '#stock_disponible?' do
      it 'returns true when sufficient stock' do
        expect(producto.stock_disponible?(10)).to be true
      end

      it 'returns false when insufficient stock' do
        expect(producto.stock_disponible?(30)).to be false
      end
    end

    describe '#tiene_stock?' do
      it 'returns true when has stock' do
        expect(producto.tiene_stock?).to be true
      end

      it 'returns false when no stock' do
        stock.update!(cantidad_actual: 0)
        expect(producto.tiene_stock?).to be false
      end
    end

    describe '#stock_bajo?' do
      it 'returns true when stock is low' do
        stock.update!(cantidad_actual: 3, cantidad_minima: 10)
        expect(producto.stock_bajo?).to be true
      end

      it 'returns false when stock is sufficient' do
        stock.update!(cantidad_actual: 15, cantidad_minima: 10)
        expect(producto.stock_bajo?).to be false
      end
    end

    describe '#stock_critico?' do
      it 'returns true when stock is critical' do
        stock.update!(cantidad_actual: 0, cantidad_minima: 10)
        producto.reload
        expect(producto.stock_critico?).to be true
      end

      it 'returns false when stock is sufficient' do
        stock.update!(cantidad_actual: 15, cantidad_minima: 10)
        expect(producto.stock_critico?).to be false
      end
    end

    describe '#reducir_stock' do
      it 'reduces stock quantity' do
        expect(producto.reducir_stock(5)).to be true
        expect(producto.stock_actual).to eq(15)
      end

      it 'returns false when insufficient stock' do
        expect(producto.reducir_stock(25)).to be false
      end
    end

    describe '#aumentar_stock' do
      it 'increases stock quantity' do
        expect(producto.aumentar_stock(10)).to be true
        expect(producto.stock_actual).to eq(30)
      end
    end
  end

  describe 'stock management with local_id' do
    let!(:producto) { create(:producto, tienda: tienda) }
    let(:local_x) { create(:local, tienda: tienda, nombre: 'Local X') }
    let(:local_y) { create(:local, tienda: tienda, nombre: 'Local Y') }

    let!(:stock_main) { producto.stocks.first.tap { |s| s.update!(cantidad_actual: 100) } }
    let!(:stock_x) do
      Productos::Stock.find_or_create_by!(producto: producto, tienda: tienda, local: local_x) do |s|
        s.cantidad_actual = 30
        s.cantidad_minima = 5
      end.tap { |s| s.update!(cantidad_actual: 30) }
    end
    let!(:stock_y) do
      Productos::Stock.find_or_create_by!(producto: producto, tienda: tienda, local: local_y) do |s|
        s.cantidad_actual = 10
        s.cantidad_minima = 2
      end.tap { |s| s.update!(cantidad_actual: 10) }
    end

    describe '#stock_actual with local_id' do
      it 'returns main stock when local_id is nil' do
        expect(producto.stock_actual(nil)).to eq(100)
      end

      it 'returns local-specific stock when local_id is given' do
        expect(producto.stock_actual(local_x.id)).to eq(30)
        expect(producto.stock_actual(local_y.id)).to eq(10)
      end

      it 'returns different quantities for different locals' do
        expect(producto.stock_actual(local_x.id)).not_to eq(producto.stock_actual(local_y.id))
      end
    end

    describe '#stock_disponible? with local_id' do
      it 'checks main stock when local_id is nil' do
        expect(producto.stock_disponible?(50, nil)).to be true
        expect(producto.stock_disponible?(200, nil)).to be false
      end

      it 'checks local-specific stock when local_id is given' do
        expect(producto.stock_disponible?(25, local_x.id)).to be true
        expect(producto.stock_disponible?(35, local_x.id)).to be false
      end
    end

    describe '#reducir_stock with local_id' do
      it 'reduces stock in the specified local only' do
        producto.reducir_stock(5, local_x.id, 'test')

        stock_x.reload
        stock_y.reload
        stock_main.reload
        expect(stock_x.cantidad_actual).to eq(25)
        expect(stock_y.cantidad_actual).to eq(10) # unchanged
        expect(stock_main.cantidad_actual).to eq(100) # unchanged
      end

      it 'reduces main stock when local_id is nil' do
        producto.reducir_stock(20, nil, 'test')

        stock_main.reload
        stock_x.reload
        expect(stock_main.cantidad_actual).to eq(80)
        expect(stock_x.cantidad_actual).to eq(30) # unchanged
      end

      it 'fails when local-specific stock is insufficient but main stock is sufficient' do
        # local_y has 10, main has 100
        result = producto.reducir_stock(50, local_y.id, 'test')
        expect(result).to be false

        stock_y.reload
        expect(stock_y.cantidad_actual).to eq(10) # unchanged
      end
    end

    describe '#aumentar_stock with local_id' do
      it 'increases stock in the specified local only' do
        producto.aumentar_stock(15, local_y.id, 'reposicion')

        stock_y.reload
        stock_x.reload
        expect(stock_y.cantidad_actual).to eq(25)
        expect(stock_x.cantidad_actual).to eq(30) # unchanged
      end
    end

    describe '#stock_for_local' do
      it 'returns different stock objects for different locals' do
        s_main = producto.stock_for_local(nil)
        s_x = producto.stock_for_local(local_x.id)
        s_y = producto.stock_for_local(local_y.id)

        expect(s_main.id).not_to eq(s_x.id)
        expect(s_x.id).not_to eq(s_y.id)
      end

      it 'returns nil when category does not have stock_activo' do
        cat_no_stock = Productos::Categoria.create!(nombre: 'No Stock', tienda: tienda, stock_activo: false)
        prod_no_stock = Productos::Producto.create!(nombre: 'Prod No Stock', categoria: cat_no_stock, tienda: tienda)

        expect(prod_no_stock.stock_for_local(local_x.id)).to be_nil
      end
    end
  end

  describe 'instance methods' do
    it 'to_s returns nombre' do
      expect(producto.to_s).to eq 'Producto Test'
    end
  end

  describe '#pesable_bloqueado?' do
    let!(:saved_producto) { create(:producto, tienda: tienda, pesable: false) }

    it 'returns false for new records' do
      expect(producto.pesable_bloqueado?).to be false
    end

    it 'returns false when stock is zero' do
      expect(saved_producto.pesable_bloqueado?).to be false
    end

    it 'returns true when stocks have non-zero quantity and categoria has stock_activo' do
      stock = saved_producto.stocks.first
      stock.update!(cantidad_actual: 10)
      expect(saved_producto.pesable_bloqueado?).to be true
    end

    it 'returns false when stocks have non-zero quantity but categoria has no stock_activo' do
      cat_no_stock = Productos::Categoria.create!(nombre: 'No Stock', tienda: tienda, stock_activo: false)
      prod = create(:producto, tienda: tienda, categoria: cat_no_stock)
      Productos::Stock.create!(producto: prod, tienda: tienda, cantidad_actual: 10)
      expect(prod.pesable_bloqueado?).to be false
    end
  end

  describe 'pesable lock validation' do
    let!(:saved_producto) { create(:producto, tienda: tienda, pesable: false) }

    it 'allows changing pesable when stock is zero and no pedidos' do
      saved_producto.pesable = true
      expect(saved_producto).to be_valid
    end

    it 'prevents changing pesable when stock is non-zero and categoria has stock_activo' do
      stock = saved_producto.stocks.first
      stock.update!(cantidad_actual: 10)
      saved_producto.pesable = true
      expect(saved_producto).not_to be_valid
      expect(saved_producto.errors[:pesable]).to include('no se puede modificar porque el producto tiene stock o pedidos asociados')
    end

    it 'allows changing pesable when stock is non-zero but categoria has no stock_activo' do
      cat_no_stock = Productos::Categoria.create!(nombre: 'No Stock', tienda: tienda, stock_activo: false)
      prod = create(:producto, tienda: tienda, categoria: cat_no_stock, pesable: false)
      Productos::Stock.create!(producto: prod, tienda: tienda, cantidad_actual: 10)
      prod.pesable = true
      expect(prod).to be_valid
    end
  end
end
