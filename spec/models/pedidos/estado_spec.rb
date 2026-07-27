require 'rails_helper'

RSpec.describe Pedidos::Estado, type: :model do
  describe 'enumeration' do
    it 'has pendiente state' do
      expect(described_class[:pendiente]).to be_present
      expect(described_class[:pendiente].id).to eq 1
      expect(described_class[:pendiente].desc).to eq 'En Carrito'
    end

    it 'has aceptado state' do
      expect(described_class[:aceptado]).to be_present
      expect(described_class[:aceptado].id).to eq 2
      expect(described_class[:aceptado].desc).to eq 'Aceptado'
    end

    it 'has confirmado state' do
      expect(described_class[:confirmado]).to be_present
      expect(described_class[:confirmado].id).to eq 3
      expect(described_class[:confirmado].desc).to eq 'Confirmado'
    end

    it 'has finalizado state' do
      expect(described_class[:finalizado]).to be_present
      expect(described_class[:finalizado].id).to eq 4
      expect(described_class[:finalizado].desc).to eq 'Finalizado'
    end

    it 'has cancelado state' do
      expect(described_class[:cancelado]).to be_present
      expect(described_class[:cancelado].id).to eq 5
      expect(described_class[:cancelado].desc).to eq 'Cancelado'
    end

    it 'can access by id' do
      expect(described_class[1].name).to eq 'pendiente'
      expect(described_class[2].name).to eq 'aceptado'
      expect(described_class[3].name).to eq 'confirmado'
      expect(described_class[4].name).to eq 'finalizado'
      expect(described_class[5].name).to eq 'cancelado'
    end

    it 'has all expected states' do
      expect(described_class.all.size).to eq 5
    end

    it 'each state has tip attribute' do
      described_class.all.each do |estado| # rubocop:disable Rails/FindEach
        expect(estado.tip).to be_present
      end
    end

    it 'pendiente tip mentions carrito' do
      expect(described_class[:pendiente].tip).to include('carrito')
    end

    it 'aceptado tip mentions aceptado' do
      expect(described_class[:aceptado].tip).to include('aceptado')
    end

    it 'confirmado tip mentions confirmado' do
      expect(described_class[:confirmado].tip).to include('confirmado')
    end

    it 'finalizado tip mentions despachado' do
      expect(described_class[:finalizado].tip).to include('despachado')
    end

    it 'cancelado tip mentions cancelado' do
      expect(described_class[:cancelado].tip).to include('cancelado')
    end

    it 'each state has name attribute' do
      described_class.all.each do |estado| # rubocop:disable Rails/FindEach
        expect(estado.name).to be_present
      end
    end
  end
end
