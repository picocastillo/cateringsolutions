require 'rails_helper'

RSpec.describe Cotizaciones::DolarApiService do
  subject(:service) { described_class.new }

  describe '#fetch_actual' do
    let(:valid_response_body) do
      {
        'moneda' => 'USD',
        'casa' => 'oficial',
        'nombre' => 'Oficial',
        'compra' => 1420.0,
        'venta' => 1425.0,
        'fechaActualizacion' => '2026-03-08T15:00:00.000Z'
      }.to_json
    end

    context 'when API returns valid response' do
      before do
        http_response = instance_double(Net::HTTPSuccess, body: valid_response_body)
        allow(http_response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
        allow(Net::HTTP).to receive(:get_response).and_return(http_response)
      end

      it 'returns parsed data with precio_venta and precio_compra' do
        result = service.fetch_actual
        expect(result[:precio_venta]).to eq(1425.0)
        expect(result[:precio_compra]).to eq(1420.0)
        expect(result[:fuente]).to eq('oficial')
        expect(result[:fecha]).to eq(Date.current)
      end
    end

    context 'when API returns error' do
      before do
        http_response = instance_double(Net::HTTPServerError, body: 'Error', code: '500')
        allow(http_response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(false)
        allow(Net::HTTP).to receive(:get_response).and_return(http_response)
        allow_any_instance_of(Kernel).to receive(:sleep)
      end

      it 'retries and returns nil after max retries' do
        expect(Net::HTTP).to receive(:get_response).exactly(5).times
        expect(service.fetch_actual).to be_nil
      end
    end

    context 'when API returns invalid data' do
      before do
        http_response = instance_double(Net::HTTPSuccess, body: { 'venta' => nil }.to_json)
        allow(http_response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
        allow(Net::HTTP).to receive(:get_response).and_return(http_response)
        allow_any_instance_of(Kernel).to receive(:sleep)
      end

      it 'retries and returns nil' do
        expect(Net::HTTP).to receive(:get_response).exactly(5).times
        expect(service.fetch_actual).to be_nil
      end
    end

    context 'when API fails then succeeds' do
      before do
        error_response = instance_double(Net::HTTPServerError, body: 'Error', code: '503')
        allow(error_response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(false)

        success_response = instance_double(Net::HTTPSuccess, body: valid_response_body)
        allow(success_response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)

        allow(Net::HTTP).to receive(:get_response).and_return(error_response, error_response, success_response)
        allow_any_instance_of(Kernel).to receive(:sleep)
      end

      it 'succeeds on third attempt' do
        expect(Net::HTTP).to receive(:get_response).exactly(3).times
        result = service.fetch_actual
        expect(result[:precio_venta]).to eq(1425.0)
      end
    end
  end

  describe '#fetch_historico' do
    let(:fecha) { Date.new(2026, 1, 15) }

    context 'when API returns valid response' do
      before do
        body = { 'fecha' => '2026-01-15', 'venta' => 1380.0, 'compra' => 1375.0 }.to_json
        http_response = instance_double(Net::HTTPSuccess, body: body)
        allow(http_response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
        allow(Net::HTTP).to receive(:get_response).and_return(http_response)
      end

      it 'returns parsed historical data' do
        result = service.fetch_historico(fecha)
        expect(result[:precio_venta]).to eq(1380.0)
        expect(result[:precio_compra]).to eq(1375.0)
        expect(result[:fecha]).to eq(fecha)
      end

      it 'calls the correct URL' do
        expect(Net::HTTP).to receive(:get_response).with(
          URI('https://api.argentinadatos.com/v1/cotizaciones/dolares/oficial/2026/01/15/')
        )
        service.fetch_historico(fecha)
      end
    end

    context 'when API returns error' do
      before do
        http_response = instance_double(Net::HTTPServerError, body: 'Error', code: '404')
        allow(http_response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(false)
        allow(Net::HTTP).to receive(:get_response).and_return(http_response)
      end

      it 'returns nil' do
        expect(service.fetch_historico(fecha)).to be_nil
      end
    end
  end

  describe '#fetch_rango' do
    let(:from_date) { Date.new(2026, 1, 10) }
    let(:to_date) { Date.new(2026, 1, 13) }

    context 'when API returns valid data' do
      before do
        body = [
          { 'fecha' => '2026-01-10T03:00:00.000Z', 'venta' => 1370.0, 'compra' => 1365.0 },
          { 'fecha' => '2026-01-11T03:00:00.000Z', 'venta' => 1375.0, 'compra' => 1370.0 },
          { 'fecha' => '2026-01-12T03:00:00.000Z', 'venta' => 1380.0, 'compra' => 1375.0 },
          { 'fecha' => '2026-01-13T03:00:00.000Z', 'venta' => 1385.0, 'compra' => 1380.0 },
          { 'fecha' => '2026-01-14T03:00:00.000Z', 'venta' => 1390.0, 'compra' => 1385.0 }
        ].to_json
        http_response = instance_double(Net::HTTPSuccess, body: body)
        allow(http_response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
        allow(Net::HTTP).to receive(:get_response).and_return(http_response)
      end

      it 'returns only dates within the requested range' do
        result = service.fetch_rango(from_date, to_date)
        expect(result.length).to eq(4)
        expect(result.first[:fecha]).to eq(from_date)
        expect(result.last[:fecha]).to eq(to_date)
      end

      it 'includes precio_venta and precio_compra' do
        result = service.fetch_rango(from_date, to_date)
        expect(result.first[:precio_venta]).to eq(1370.0)
        expect(result.first[:precio_compra]).to eq(1365.0)
      end
    end

    context 'when API returns error' do
      before do
        http_response = instance_double(Net::HTTPServerError, body: 'Error', code: '500')
        allow(http_response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(false)
        allow(Net::HTTP).to receive(:get_response).and_return(http_response)
      end

      it 'returns nil' do
        expect(service.fetch_rango(from_date, to_date)).to be_nil
      end
    end

    context 'when API returns non-array response' do
      before do
        http_response = instance_double(Net::HTTPSuccess, body: { 'error' => 'not found' }.to_json)
        allow(http_response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
        allow(Net::HTTP).to receive(:get_response).and_return(http_response)
      end

      it 'returns nil' do
        expect(service.fetch_rango(from_date, to_date)).to be_nil
      end
    end
  end
end
