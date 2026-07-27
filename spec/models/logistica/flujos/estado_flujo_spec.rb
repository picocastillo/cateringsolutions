require 'rails_helper'

RSpec.describe Logistica::Flujos::EstadoFlujo, type: :model do
  describe 'enumeration' do
    it 'has pendiente state' do
      expect(described_class[:pendiente]).to be_present
      expect(described_class[:pendiente].desc).to eq 'Pendiente'
      expect(described_class[:pendiente].tip).to eq 'Listo para confirmar e imputar pagos.'
    end

    it 'has anulado state' do
      expect(described_class[:anulado]).to be_present
      expect(described_class[:anulado].desc).to eq 'Anulado'
      expect(described_class[:anulado].tip).to eq 'El recibo ha sido anulado.'
    end

    it 'has confirmado state' do
      expect(described_class[:confirmado]).to be_present
      expect(described_class[:confirmado].desc).to eq 'Confirmado'
      expect(described_class[:confirmado].tip).to eq 'El recibo ha sido confirmado.'
    end

    it 'has finalizado state' do
      expect(described_class[:finalizado]).to be_present
      expect(described_class[:finalizado].desc).to eq 'Finalizado'
      expect(described_class[:finalizado].tip).to eq 'El recibo ha sido finalizado. No se pueden realizar más afectaciones.'
    end

    it 'has exactly 4 states' do
      expect(described_class.all.size).to eq 4
    end

    it 'can access by symbol' do
      expect(described_class[:pendiente].name).to eq 'pendiente'
      expect(described_class[:anulado].name).to eq 'anulado'
      expect(described_class[:confirmado].name).to eq 'confirmado'
      expect(described_class[:finalizado].name).to eq 'finalizado'
    end
  end

  describe '#to_s' do
    it 'returns desc for pendiente' do
      expect(described_class[:pendiente].to_s).to eq 'Pendiente'
    end

    it 'returns desc for anulado' do
      expect(described_class[:anulado].to_s).to eq 'Anulado'
    end

    it 'returns desc for confirmado' do
      expect(described_class[:confirmado].to_s).to eq 'Confirmado'
    end

    it 'returns desc for finalizado' do
      expect(described_class[:finalizado].to_s).to eq 'Finalizado'
    end
  end

  describe '.find_by_desc' do
    it 'finds estado by description' do
      estado = described_class.all.find { |e| e.desc == 'Pendiente' }
      expect(estado).to eq described_class[:pendiente]
    end

    it 'returns nil for non-existent description' do
      estado = described_class.all.find { |e| e.desc == 'NoExiste' }
      expect(estado).to be_nil
    end
  end

  describe '.find_by_name' do
    it 'finds estado by name' do
      estado = described_class.all.find { |e| e.name == 'pendiente' }
      expect(estado).to eq described_class[:pendiente]
    end

    it 'returns nil for non-existent name' do
      estado = described_class.all.find { |e| e.name == 'no_existe' }
      expect(estado).to be_nil
    end
  end
end
