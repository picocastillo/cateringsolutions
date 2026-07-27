require 'rails_helper'

RSpec.describe ExcelImporter do
  let(:importer) { described_class.new }
  let(:user) { create(:usuario) }

  before do
    allow(importer).to receive_messages(autor: user, adjunto: double('Attachment', path: 'test.xlsx'), adjunto_file_name: 'planilla.xlsx')
  end

  describe 'validations' do
    it 'has format validation configured' do
      expect(described_class.validators.map(&:class)).to include(ActiveModel::Validations::FormatValidator)
    end
  end

  describe '#row_num' do
    it 'defaults to 1' do
      expect(importer.row_num).to eq(1)
    end

    it 'can be set' do
      importer.row_num = 5
      expect(importer.row_num).to eq(5)
    end
  end

  describe '#headers' do
    it 'has headers reader' do
      expect(importer).to respond_to(:headers)
    end
  end

  describe '#perform' do
    it 'delegates to run with adjunto path' do
      allow(importer).to receive(:run)
      importer.perform
      expect(importer).to have_received(:run).with('test.xlsx')
    end
  end

  describe '#run' do
    let(:sheet) do
      s = double('Sheet', last_row: 2)
      allow(s).to receive(:row).with(1).and_return(['Name', 'Code'])
      allow(s).to receive(:row).with(2).and_return(['Test', '001'])
      s
    end

    let(:spreadsheet) { double('Spreadsheet') }
    let(:progreso) { double('Progreso') }

    before do
      allow(spreadsheet).to receive(:sheet).with(0).and_return(sheet)
      allow(Roo::Spreadsheet).to receive(:open).and_return(spreadsheet)
      allow(importer).to receive(:progreso).and_return(progreso)
      allow(progreso).to receive(:track).and_yield
      allow(progreso).to receive(:fue_cancelado?).and_return(false)
      allow(progreso).to receive(:avanzar)
      allow(importer).to receive(:process_row)
      allow(importer).to receive(:save!)
    end

    it 'sets headers from first row' do
      importer.run('test.xlsx')
      expect(importer.headers).to eq ['Name', 'Code']
    end

    it 'processes each row as a hash' do
      importer.run('test.xlsx')
      expect(importer).to have_received(:process_row).with('Name' => 'Test', 'Code' => '001')
    end

    it 'increments row_num' do
      importer.run('test.xlsx')
      expect(importer.row_num).to eq 2
    end

    it 'saves after processing' do
      importer.run('test.xlsx')
      expect(importer).to have_received(:save!)
    end

    it 'skips empty rows' do
      allow(sheet).to receive(:row).with(2).and_return([nil, nil])

      importer.run('test.xlsx')
      expect(importer).not_to have_received(:process_row)
    end

    it 'stops on cancellation' do
      allow(sheet).to receive(:last_row).and_return(3)
      allow(sheet).to receive(:row).with(3).and_return(['Never', '002'])
      allow(progreso).to receive(:fue_cancelado?).and_return(true)

      importer.run('test.xlsx')
      expect(importer).to have_received(:process_row).once
    end

    it 'handles RecordInvalid errors gracefully' do
      error = ActiveRecord::RecordInvalid.allocate
      record = double('Record', errors: double('Errors', full_messages: ['Name is invalid']))
      error.instance_variable_set(:@record, record)
      allow(importer).to receive(:process_row).and_raise(error)
      allow(importer).to receive(:error!)
      allow(importer).to receive(:logger).and_return(double(error: nil))

      importer.run('test.xlsx')
      expect(importer).to have_received(:error!).with(/Error en fila 2/)
    end
  end

  describe '#open_spreadsheet (private)' do
    it 'always opens with xlsx extension' do
      expect(Roo::Spreadsheet).to receive(:open).with('/tmp/file', extension: 'xlsx').and_return(double)

      importer.send(:open_spreadsheet, '/tmp/file')
    end
  end

  describe 'xls file rejection' do
    let(:attachment) { double('Attachment', path: 'test.xlsx', flush_errors: nil, dirty?: false) }

    it 'rejects .xls files via format validation' do
      allow(importer).to receive_messages(adjunto: attachment, adjunto_file_name: 'planilla.xls')
      importer.valid?
      expect(importer.errors[:adjunto_file_name].join).to include('.xlsx')
    end

    it 'accepts .xlsx files' do
      allow(importer).to receive_messages(adjunto: attachment, adjunto_file_name: 'planilla.xlsx')
      importer.valid?
      expect(importer.errors[:adjunto_file_name]).to be_empty
    end
  end
end
