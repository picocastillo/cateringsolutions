require 'rails_helper'

RSpec.describe Cotizaciones::Dolar, type: :model do
  describe 'validations' do
    it 'requires fecha' do
      dolar = described_class.new(precio_venta: 1425.0)
      expect(dolar).not_to be_valid
      expect(dolar.errors[:fecha]).to be_present
    end

    it 'requires precio_venta' do
      dolar = described_class.new(fecha: Date.current)
      expect(dolar).not_to be_valid
      expect(dolar.errors[:precio_venta]).to be_present
    end

    it 'requires precio_venta > 0' do
      dolar = described_class.new(fecha: Date.current, precio_venta: -1)
      expect(dolar).not_to be_valid
    end

    it 'enforces unique fecha' do
      described_class.create!(fecha: Date.current, precio_venta: 1425.0)
      dolar = described_class.new(fecha: Date.current, precio_venta: 1430.0)
      expect(dolar).not_to be_valid
      expect(dolar.errors[:fecha]).to be_present
    end

    it 'is valid with all required fields' do
      dolar = described_class.new(fecha: Date.current, precio_venta: 1425.0)
      expect(dolar).to be_valid
    end

    it 'defaults fuente to oficial' do
      dolar = described_class.create!(fecha: Date.current, precio_venta: 1425.0)
      expect(dolar.fuente).to eq('oficial')
    end
  end

  describe '.precio_para_fecha' do
    it 'returns precio_venta for exact date match' do
      described_class.create!(fecha: Date.current, precio_venta: 1425.0)
      expect(described_class.precio_para_fecha(Date.current)).to eq(1425.0)
    end

    it 'falls back to most recent previous date when exact date not found' do
      described_class.create!(fecha: 3.days.ago.to_date, precio_venta: 1400.0)
      described_class.create!(fecha: 1.day.ago.to_date, precio_venta: 1420.0)
      expect(described_class.precio_para_fecha(Date.current)).to eq(1420.0)
    end

    it 'returns nil when no data exists at all' do
      expect(described_class.precio_para_fecha(Date.current)).to be_nil
    end

    it 'falls back to latest available rate for future pedido dates' do
      described_class.create!(fecha: 1.day.from_now.to_date, precio_venta: 1425.0)
      expect(described_class.precio_para_fecha(Date.current)).to eq(1425.0)
    end

    it 'enqueues background job when today is missing' do
      described_class.create!(fecha: 1.day.ago.to_date, precio_venta: 1420.0)

      expect do
        described_class.precio_para_fecha(Date.current)
      end.to have_enqueued_job(Cotizaciones::ActualizarDolarJob).with(Date.current.to_s)
    end

    it 'does not enqueue job for past dates' do
      expect do
        described_class.precio_para_fecha(1.day.ago.to_date)
      end.not_to have_enqueued_job(Cotizaciones::ActualizarDolarJob)
    end

    it 'does not enqueue job when today exists' do
      described_class.create!(fecha: Date.current, precio_venta: 1425.0)

      expect do
        described_class.precio_para_fecha(Date.current)
      end.not_to have_enqueued_job(Cotizaciones::ActualizarDolarJob)
    end

    it 'handles datetime inputs by converting to date' do
      described_class.create!(fecha: Date.current, precio_venta: 1425.0)
      expect(described_class.precio_para_fecha(Time.current)).to eq(1425.0)
    end
  end

  describe '.precio_hoy' do
    it 'returns today\'s precio_venta' do
      described_class.create!(fecha: Date.current, precio_venta: 1430.0)
      expect(described_class.precio_hoy).to eq(1430.0)
    end

    it 'falls back to yesterday when today is missing' do
      described_class.create!(fecha: 1.day.ago.to_date, precio_venta: 1420.0)
      expect(described_class.precio_hoy).to eq(1420.0)
    end
  end

  describe '.actualizar!' do
    let(:service) { instance_double(Cotizaciones::DolarApiService) }

    before do
      allow(Cotizaciones::DolarApiService).to receive(:new).and_return(service)
    end

    it 'fetches current rate and creates record for today' do
      allow(service).to receive(:fetch_actual).and_return(
        { fecha: Date.current, precio_venta: 1425.0, precio_compra: 1420.0, fuente: 'oficial' }
      )

      registro = described_class.actualizar!
      expect(registro).to be_persisted
      expect(registro.fecha).to eq(Date.current)
      expect(registro.precio_venta).to eq(1425.0)
      expect(registro.precio_compra).to eq(1420.0)
    end

    it 'skips API call when today already exists' do
      described_class.create!(fecha: Date.current, precio_venta: 1400.0)
      expect(service).not_to receive(:fetch_actual)

      registro = described_class.actualizar!
      expect(registro.precio_venta).to eq(1400.0)
    end

    it 'fetches historical rate for past dates' do
      fecha = 5.days.ago.to_date
      allow(service).to receive(:fetch_historico).with(fecha).and_return(
        { fecha: fecha, precio_venta: 1410.0, precio_compra: 1405.0, fuente: 'oficial' }
      )

      registro = described_class.actualizar!(fecha)
      expect(registro.fecha).to eq(fecha)
      expect(registro.precio_venta).to eq(1410.0)
    end

    it 'returns nil when API fails' do
      allow(service).to receive(:fetch_actual).and_return(nil)
      expect(described_class.actualizar!).to be_nil
    end
  end

  describe '.backfill!' do
    let(:service) { instance_double(Cotizaciones::DolarApiService) }

    before do
      allow(Cotizaciones::DolarApiService).to receive(:new).and_return(service)
    end

    it 'creates records for dates returned by API' do
      from_date = 3.days.ago.to_date
      datos = [
        { fecha: 3.days.ago.to_date, precio_venta: 1400.0, precio_compra: 1395.0, fuente: 'oficial' },
        { fecha: 2.days.ago.to_date, precio_venta: 1410.0, precio_compra: 1405.0, fuente: 'oficial' },
        { fecha: 1.day.ago.to_date, precio_venta: 1420.0, precio_compra: 1415.0, fuente: 'oficial' }
      ]
      allow(service).to receive(:fetch_rango).with(from_date, Date.current).and_return(datos)

      count = described_class.backfill!(from_date: from_date)
      expect(count).to eq(3)
      expect(described_class.count).to eq(3)
    end

    it 'skips dates that already exist' do
      from_date = 2.days.ago.to_date
      described_class.create!(fecha: 2.days.ago.to_date, precio_venta: 1410.0)

      datos = [
        { fecha: 2.days.ago.to_date, precio_venta: 1410.0, precio_compra: 1405.0, fuente: 'oficial' },
        { fecha: 1.day.ago.to_date, precio_venta: 1420.0, precio_compra: 1415.0, fuente: 'oficial' }
      ]
      allow(service).to receive(:fetch_rango).with(from_date, Date.current).and_return(datos)

      count = described_class.backfill!(from_date: from_date)
      expect(count).to eq(1)
      expect(described_class.count).to eq(2)
    end

    it 'returns 0 when API returns nil' do
      allow(service).to receive(:fetch_rango).and_return(nil)
      expect(described_class.backfill!(from_date: 3.days.ago.to_date)).to eq(0)
    end
  end
end
