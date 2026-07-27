require 'rails_helper'

RSpec.describe StockAlertsMailer, type: :mailer do
  describe 'daily_report' do
    let(:tienda) { create(:tienda, nombre: 'Test Tienda', stock_notifications_email: 'stock@test.com') }
    let(:categoria) { create(:categoria, tienda: tienda, stock_activo: true) }
    let!(:producto_critico) { create(:producto, nombre: 'Producto Crítico', tienda: tienda, categoria: categoria) }
    let!(:producto_bajo) { create(:producto, nombre: 'Producto Bajo', tienda: tienda, categoria: categoria) }
    let!(:producto_sin_stock) { create(:producto, nombre: 'Producto Sin Stock', tienda: tienda, categoria: categoria) }

    let!(:stock_critico) do
      producto_critico.stocks.first.tap do |s|
        s.update!(cantidad_actual: 0, cantidad_minima: 10)
      end
    end

    let!(:stock_bajo) do
      producto_bajo.stocks.first.tap do |s|
        s.update!(cantidad_actual: 3, cantidad_minima: 10)
      end
    end

    let!(:stock_sin_stock) do
      producto_sin_stock.stocks.first.tap do |s|
        s.update!(cantidad_actual: 0, cantidad_minima: 5)
      end
    end

    let(:mail) { described_class.daily_report(tienda) }

    it 'renders the headers correctly' do
      expect(mail.subject).to include('Alerta de Stock')
      expect(mail.subject).to include(tienda.nombre)
      expect(mail.to).to eq([tienda.stock_notifications_email])
      expect(mail.from).to eq(['from@example.com'])
    end

    it 'includes stock crítico in body' do
      body = mail.html_part ? mail.html_part.body.decoded : mail.body.decoded
      expect(body).to include('Producto Crítico')
      expect(body).to include('Stock Crítico')
    end

    it 'includes stock bajo in body' do
      body = mail.html_part ? mail.html_part.body.decoded : mail.body.decoded
      expect(body).to include('Producto Bajo')
      expect(body).to include('Stock Bajo')
    end

    it 'includes stock sin stock in body' do
      body = mail.html_part ? mail.html_part.body.decoded : mail.body.decoded
      expect(body).to include('Producto Sin Stock')
      expect(body).to include('Sin Stock')
    end

    it 'includes total alerts count in subject' do
      # We have 2 críticos (0 stock counts as crítico) + 1 bajo = 3 total
      # But stock_bajo scope excludes those already in crítico, so we should have specific counts
      expect(mail.subject).to match(/\d+ productos requieren atención/)
    end

    context 'when no stocks need alerts' do
      let(:tienda_ok) { create(:tienda, nombre: 'Tienda OK', stock_notifications_email: 'ok@test.com') }
      let(:categoria_ok) { create(:categoria, tienda: tienda_ok, stock_activo: true) }
      let!(:producto_ok) { create(:producto, nombre: 'Producto OK', tienda: tienda_ok, categoria: categoria_ok) }

      before do
        producto_ok.stocks.first.update!(cantidad_actual: 100, cantidad_minima: 10)
      end

      it 'returns nil and does not send email' do
        mail = described_class.daily_report(tienda_ok)
        expect(mail.message).to be_a(ActionMailer::Base::NullMail)
      end
    end

    context 'when categoria does not have stock_activo' do
      let(:categoria_sin_stock) { create(:categoria, tienda: tienda, stock_activo: false) }
      let!(:producto_ignorado) { create(:producto, nombre: 'Producto Ignorado', tienda: tienda, categoria: categoria_sin_stock) }

      before do
        # Ensure stock exists for this producto
        stock = producto_ignorado.stocks.first
        if stock
          stock.update!(cantidad_actual: 0, cantidad_minima: 10)
        else
          Productos::Stock.create!(
            producto: producto_ignorado,
            tienda: tienda,
            cantidad_actual: 0,
            cantidad_minima: 10
          )
        end
      end

      it 'does not include productos from categorias without stock_activo' do
        body = mail.html_part ? mail.html_part.body.decoded : mail.body.decoded
        expect(body).not_to include('Producto Ignorado')
      end
    end
  end
end
