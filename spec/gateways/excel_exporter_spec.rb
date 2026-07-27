require 'rails_helper'

RSpec.describe ExcelExporter do
  let(:tienda) { create(:tienda) }
  let(:autor) { create(:usuario, :admin, visualizando_tienda: tienda) }
  let(:exporter) { described_class.new(autor: autor, tienda: tienda, params: {}) }

  describe 'format setup' do
    it 'sets up formats when setup_formats is called' do
      wb = WriteXLSX.new(StringIO.new)
      exporter.instance_variable_set(:@workbook, wb)
      exporter.send(:setup_formats)
      expect(exporter.instance_variable_get(:@header_format)).not_to be_nil
      expect(exporter.instance_variable_get(:@currency_format)).not_to be_nil
      expect(exporter.instance_variable_get(:@percent_format)).not_to be_nil
      expect(exporter.instance_variable_get(:@date_format)).not_to be_nil
      wb.close
    end
  end

  describe '#rows' do
    it 'returns array with row when record method not defined' do
      allow(exporter).to receive(:row).and_return(['A', 'B', 'C'])
      result = exporter.rows(double('Object'))
      expect(result).to eq([['A', 'B', 'C']])
    end
  end

  describe '#process_params (before_save callback)' do
    context 'when params have string keys (YAML deserialization)' do
      it 'normalizes string keys to symbols' do
        exp = described_class.new(autor: autor, tienda: tienda, params: { 'id' => 42, 'q' => { 'fecha' => '2026-01-01' } })
        exp.valid? # triggers before_save callbacks
        exp.run_callbacks(:save)

        expect(exp.params[:id]).to eq(42)
        expect(exp.params[:q]).to eq({ fecha: '2026-01-01' })
      end
    end

    context 'when params have mixed string and symbol keys' do
      it 'normalizes all to symbols' do
        exp = described_class.new(autor: autor, tienda: tienda, params: { 'id' => 1, zippear: true })
        exp.run_callbacks(:save)

        expect(exp.params.keys).to all(be_a(Symbol))
        expect(exp.params[:id]).to eq(1)
        expect(exp.params[:zippear]).to be(true)
      end
    end

    context 'when params already have symbol keys' do
      it 'keeps them as symbols' do
        exp = described_class.new(autor: autor, tienda: tienda, params: { id: 99 })
        exp.run_callbacks(:save)

        expect(exp.params[:id]).to eq(99)
      end
    end

    it 'sets zippear to true by default when not present' do
      exp = described_class.new(autor: autor, tienda: tienda, params: { id: 1 })
      exp.run_callbacks(:save)

      expect(exp.params[:zippear]).to be(true)
    end

    it 'does not override zippear when already set to false' do
      exp = described_class.new(autor: autor, tienda: tienda, params: { zippear: false })
      exp.run_callbacks(:save)

      expect(exp.params[:zippear]).to be(false)
    end

    it 'does not create duplicate zippear keys from mixed string/symbol' do
      exp = described_class.new(autor: autor, tienda: tienda, params: { 'zippear' => false })
      exp.run_callbacks(:save)

      # After deep_symbolize_keys, only the symbol key should exist
      expect(exp.params.keys.count(:zippear)).to eq(1)
      expect(exp.params[:zippear]).to be(false)
    end
  end

  describe 'YAML serialization round-trip' do
    it 'preserves params through save and reload' do
      exp = described_class.new(autor: autor, tienda: tienda, params: { id: 42, q: { fecha: '2026-01-01' } })
      exp.save!

      reloaded = described_class.find(exp.id)
      # After process_params normalizes + YAML round-trip, keys should be accessible as symbols
      expect(reloaded.params[:id]).to eq(42)
      expect(reloaded.params[:q][:fecha]).to eq('2026-01-01')
    end

    it 'handles params that come back with string keys after YAML reload' do
      exp = described_class.new(autor: autor, tienda: tienda, params: { id: 42 })
      exp.save!

      reloaded = described_class.find(exp.id)
      # Simulate what process_params does — even if YAML gives strings back,
      # using with_indifferent_access or deep_symbolize_keys should work
      p = reloaded.params
      p = p.deep_symbolize_keys if p.is_a?(Hash)
      expect(p[:id]).to eq(42)
    end
  end

  describe '#xlsx_filepath' do
    it 'strips .zip extension to get .xlsx path' do
      adjunto = double('Adjunto', path: '/tmp/export_2026-02-19.zip')
      allow(exporter).to receive(:adjunto).and_return(adjunto)
      expect(exporter.xlsx_filepath).to eq('/tmp/export_2026-02-19.xlsx')
    end
  end

  describe '#each_object_con_progreso_y_cancelacion' do
    let(:progreso) { double('Progreso') }

    before do
      allow(exporter).to receive(:progreso).and_return(progreso)
      allow(progreso).to receive(:fue_cancelado?).and_return(false)
      allow(progreso).to receive(:avanzar)
    end

    it 'yields each object' do
      objects = double('Objects')
      allow(exporter).to receive(:enumerable).with(objects).and_return([1, 2, 3])

      collected = []
      exporter.each_object_con_progreso_y_cancelacion(objects) { |o| collected << o }
      expect(collected).to eq [1, 2, 3]
    end

    it 'stops on cancellation' do
      objects = double('Objects')
      allow(exporter).to receive(:enumerable).with(objects).and_return([1, 2, 3])
      call_count = 0
      allow(progreso).to receive(:fue_cancelado?) do
        call_count += 1
        call_count > 1
      end

      collected = []
      exporter.each_object_con_progreso_y_cancelacion(objects) { |o| collected << o }
      expect(collected).to eq [1]
    end

    it 'finishes with error on exception' do
      objects = double('Objects')
      allow(exporter).to receive(:enumerable).with(objects).and_return([1])
      allow(progreso).to receive(:finish_with_error)
      boom = proc { raise StandardError, 'boom' }

      expect do
        exporter.each_object_con_progreso_y_cancelacion(objects) { |_o| boom.call }
      end.to raise_error(StandardError, 'boom')
      expect(progreso).to have_received(:finish_with_error).with('boom')
    end
  end

  describe 'private methods' do
    describe '#name' do
      it 'strips Exporter suffix from class name' do
        expect(exporter.send(:name)).to eq 'Excel'
      end
    end

    describe '#filename_prefix' do
      it 'underscores the name' do
        expect(exporter.send(:filename_prefix)).to eq 'excel'
      end
    end

    describe '#crear_encabezados' do
      it 'writes headers from headers method when defined' do
        wb = WriteXLSX.new(StringIO.new)
        sheet = wb.add_worksheet
        exporter.instance_variable_set(:@workbook, wb)
        exporter.send(:setup_formats)
        exporter.instance_variable_set(:@current_row, 0)
        allow(exporter).to receive(:respond_to?).and_call_original
        allow(exporter).to receive(:respond_to?).with(:headers).and_return(true)
        allow(exporter).to receive(:headers).and_return(['Col A', 'Col B'])

        exporter.send(:crear_encabezados, sheet, [])
        expect(exporter.instance_variable_get(:@current_row)).to eq 1
        wb.close
      end

      it 'writes record keys from first object when no headers method' do
        wb = WriteXLSX.new(StringIO.new)
        sheet = wb.add_worksheet
        exporter.instance_variable_set(:@workbook, wb)
        exporter.send(:setup_formats)
        exporter.instance_variable_set(:@current_row, 0)
        obj = double('Obj')
        allow(exporter).to receive(:respond_to?).and_call_original
        allow(exporter).to receive(:respond_to?).with(:headers).and_return(false)
        allow(exporter).to receive(:record).with(obj).and_return({ 'name' => 'A', 'code' => 'B' })

        exporter.send(:crear_encabezados, sheet, [obj])
        expect(exporter.instance_variable_get(:@current_row)).to eq 1
        wb.close
      end
    end

    describe '#crear_footers' do
      it 'writes nothing when footers not defined' do
        wb = WriteXLSX.new(StringIO.new)
        sheet = wb.add_worksheet
        exporter.instance_variable_set(:@workbook, wb)
        exporter.send(:setup_formats)
        exporter.instance_variable_set(:@current_row, 0)

        exporter.send(:crear_footers, sheet, [])
        expect(exporter.instance_variable_get(:@current_row)).to eq 0
        wb.close
      end

      it 'writes array footers' do
        wb = WriteXLSX.new(StringIO.new)
        sheet = wb.add_worksheet
        exporter.instance_variable_set(:@workbook, wb)
        exporter.send(:setup_formats)
        exporter.instance_variable_set(:@current_row, 0)
        allow(exporter).to receive(:respond_to?).and_call_original
        allow(exporter).to receive(:respond_to?).with(:footers).and_return(true)
        allow(exporter).to receive(:footers).and_return([['Total', 100], ['Count', 5]])

        exporter.send(:crear_footers, sheet, [])
        expect(exporter.instance_variable_get(:@current_row)).to eq 2
        wb.close
      end
    end

    describe '#convert_types' do
      it 'converts Money to float' do
        result = exporter.send(:convert_types, [Danconia::Money.new(100)])
        expect(result.first).to eq 100.0
      end

      it 'converts booleans to sino' do
        result = exporter.send(:convert_types, [true, false])
        expect(result).to eq ['Si', 'No']
      end

      it 'converts nil to empty string' do
        result = exporter.send(:convert_types, [nil])
        expect(result).to eq ['']
      end

      it 'keeps Date as Date' do
        date = Time.zone.today
        result = exporter.send(:convert_types, [date])
        expect(result.first).to eq date
      end
    end
  end
end
