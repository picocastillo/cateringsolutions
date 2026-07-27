require 'rails_helper'

RSpec.describe Productos::PreciosImporter, type: :gateway do
  let(:tienda) { create(:tienda) }
  let(:usuario) { create(:usuario, visualizando_tienda: tienda) }
  let(:categoria) { create(:categoria, tienda: tienda) }
  let(:producto) { create(:producto, tienda: tienda, categoria: categoria) }

  let(:importer) do
    described_class.new(
      params: {},
      autor: usuario
    )
  end

  describe '#parse_fecha' do
    it 'returns nil for blank value' do
      expect(importer.parse_fecha(nil)).to be_nil
      expect(importer.parse_fecha('')).to be_nil
    end

    it 'returns Date objects as-is' do
      date = Date.new(2026, 4, 8)
      expect(importer.parse_fecha(date)).to eq(date)
    end

    it 'converts String to date via .to_date' do
      expect(importer.parse_fecha('2026-04-08')).to eq(Date.new(2026, 4, 8))
    end

    it 'converts Integer (Excel serial date) to Date' do
      # Hardcoded: Excel serial 46120 = April 8, 2026 (verified independently)
      expect(importer.parse_fecha(46_120)).to eq(Date.new(2026, 4, 8))
    end

    it 'converts Float (Excel serial date) to Date' do
      # Hardcoded: Excel serial 45823 = June 15, 2025 (verified independently)
      expect(importer.parse_fecha(45_823.0)).to eq(Date.new(2025, 6, 15))
    end

    it 'does not shift date by off-by-one when converting serial' do
      # Hardcoded: Excel serial 46023 = January 1, 2026
      result = importer.parse_fecha(46_023)
      expect(result).to eq(Date.new(2026, 1, 1))
      expect(result.day).to eq(1)
      expect(result.month).to eq(1)
      expect(result.year).to eq(2026)
    end

    it 'converts DateTime to Date' do
      datetime = DateTime.new(2026, 4, 8, 14, 30, 0)
      result = importer.parse_fecha(datetime)
      expect(result).to eq(Date.new(2026, 4, 8))
    end

    it 'converts Time to Date' do
      time = Time.zone.local(2026, 4, 8, 10, 0, 0)
      expect(importer.parse_fecha(time)).to eq(Date.new(2026, 4, 8))
    end
  end

  describe '#process_row' do
    context 'creating new precio with Date objects (Spreadsheet parsed dates)' do
      it 'creates a precio with fecha_desde and fecha_hasta' do
        row = {
          'Código Producto' => producto.codigo,
          'Importe' => 250.0,
          'Fecha Desde' => Date.new(2026, 4, 1),
          'Fecha Hasta' => Date.new(2026, 12, 31)
        }

        expect { importer.process_row(row) }.to change(Productos::Precio, :count).by(1)

        precio = Productos::Precio.last
        expect(precio.producto).to eq(producto)
        expect(precio.importe).to eq(250.0)
        expect(precio.fecha_desde).to eq(Date.new(2026, 4, 1))
        expect(precio.fecha_hasta).to eq(Date.new(2026, 12, 31))
      end
    end

    context 'creating new precio with Integer dates (Excel serial numbers)' do
      it 'creates a precio converting integer serial dates correctly' do
        fecha_desde_serial = (Date.new(2026, 4, 1) - described_class::EXCEL_EPOCH).to_i
        fecha_hasta_serial = (Date.new(2026, 12, 31) - described_class::EXCEL_EPOCH).to_i

        row = {
          'Código Producto' => producto.codigo,
          'Importe' => 300.0,
          'Fecha Desde' => fecha_desde_serial,
          'Fecha Hasta' => fecha_hasta_serial
        }

        expect { importer.process_row(row) }.to change(Productos::Precio, :count).by(1)

        precio = Productos::Precio.last
        expect(precio.fecha_desde).to eq(Date.new(2026, 4, 1))
        expect(precio.fecha_hasta).to eq(Date.new(2026, 12, 31))
      end

      it 'does not raise NoMethodError for integer fecha_desde' do
        serial = (Date.new(2026, 6, 15) - described_class::EXCEL_EPOCH).to_i

        row = {
          'Código Producto' => producto.codigo,
          'Importe' => 100.0,
          'Fecha Desde' => serial
        }

        expect { importer.process_row(row) }.not_to raise_error
      end

      it 'does not raise NoMethodError for integer fecha_hasta' do
        serial = (Date.new(2026, 6, 15) - described_class::EXCEL_EPOCH).to_i

        row = {
          'Código Producto' => producto.codigo,
          'Importe' => 100.0,
          'Fecha Desde' => Date.new(2026, 1, 1),
          'Fecha Hasta' => serial
        }

        expect { importer.process_row(row) }.not_to raise_error
      end
    end

    context 'updating existing precio with Integer dates' do
      let!(:precio_existente) do
        create(:precio, producto: producto, importe: 200.0,
                        fecha_desde: Date.new(2026, 1, 1), fecha_hasta: Date.new(2026, 6, 30))
      end

      it 'updates fecha_desde and fecha_hasta from integer serial dates' do
        new_desde_serial = (Date.new(2026, 3, 1) - described_class::EXCEL_EPOCH).to_i
        new_hasta_serial = (Date.new(2026, 9, 30) - described_class::EXCEL_EPOCH).to_i

        row = {
          'Código Producto' => producto.codigo,
          'idPrecio' => precio_existente.id,
          'Importe' => 200.0,
          'Fecha Desde' => new_desde_serial,
          'Fecha Hasta' => new_hasta_serial
        }

        importer.process_row(row)
        precio_existente.reload

        expect(precio_existente.fecha_desde).to eq(Date.new(2026, 3, 1))
        expect(precio_existente.fecha_hasta).to eq(Date.new(2026, 9, 30))
      end
    end

    context 'with String dates' do
      it 'parses string fecha_desde and fecha_hasta' do
        row = {
          'Código Producto' => producto.codigo,
          'Importe' => 175.0,
          'Fecha Desde' => '2026-05-01',
          'Fecha Hasta' => '2026-11-30'
        }

        expect { importer.process_row(row) }.to change(Productos::Precio, :count).by(1)

        precio = Productos::Precio.last
        expect(precio.fecha_desde).to eq(Date.new(2026, 5, 1))
        expect(precio.fecha_hasta).to eq(Date.new(2026, 11, 30))
      end
    end

    context 'without dates' do
      it 'creates precio without fecha_hasta when not provided' do
        row = {
          'Código Producto' => producto.codigo,
          'Importe' => 120.0
        }

        expect { importer.process_row(row) }.to change(Productos::Precio, :count).by(1)

        precio = Productos::Precio.last
        expect(precio.fecha_hasta).to be_nil
      end
    end
  end
end
