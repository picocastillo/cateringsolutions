require 'rails_helper'
require 'rake'

RSpec.describe 'cotizacion rake tasks' do
  before(:all) do
    Rake.application.rake_require 'tasks/cotizacion'
    Rake::Task.define_task(:environment)
  end

  describe 'cotizacion:actualizar_dolar' do
    let(:task) { Rake::Task['cotizacion:actualizar_dolar'] }

    before { task.reenable }

    context 'when API returns valid response' do
      before do
        service = instance_double(Cotizaciones::DolarApiService)
        allow(Cotizaciones::DolarApiService).to receive(:new).and_return(service)
        allow(service).to receive(:fetch_actual).and_return(
          { fecha: Date.current, precio_venta: 1425.0, precio_compra: 1420.0, fuente: 'oficial' }
        )
      end

      it 'creates a cotizacion record for today' do
        expect { task.invoke }.to output(/Cotización del dólar actualizada/).to_stdout
        registro = Cotizaciones::Dolar.find_by(fecha: Date.current)
        expect(registro).to be_present
        expect(registro.precio_venta.to_f).to eq(1425.0)
      end
    end

    context 'when API fails' do
      before do
        service = instance_double(Cotizaciones::DolarApiService)
        allow(Cotizaciones::DolarApiService).to receive(:new).and_return(service)
        allow(service).to receive(:fetch_actual).and_return(nil)
      end

      it 'aborts with error message' do
        expect { task.invoke }.to raise_error(SystemExit, /Error al obtener cotización/)
      end
    end
  end

  describe 'cotizacion:backfill' do
    let(:task) { Rake::Task['cotizacion:backfill'] }

    before { task.reenable }

    context 'with from_date argument' do
      before do
        service = instance_double(Cotizaciones::DolarApiService)
        allow(Cotizaciones::DolarApiService).to receive(:new).and_return(service)
        allow(service).to receive(:fetch_rango).and_return([
                                                             { fecha: 2.days.ago.to_date, precio_venta: 1420.0, precio_compra: 1415.0, fuente: 'oficial' },
                                                             { fecha: 1.day.ago.to_date, precio_venta: 1425.0, precio_compra: 1420.0, fuente: 'oficial' }
                                                           ])
      end

      it 'backfills from the given date' do
        expect { task.invoke(2.days.ago.to_date.to_s) }.to output(/Backfill completado: 2 cotizaciones/).to_stdout
      end
    end

    context 'without from_date argument (uses first comprobante)' do
      it 'outputs message when no comprobantes exist' do
        allow(Comprobantes::Comprobante).to receive(:minimum).with(:fecha_emision).and_return(nil)
        expect { task.invoke }.to output(/No hay comprobantes/).to_stdout
      end
    end
  end
end
