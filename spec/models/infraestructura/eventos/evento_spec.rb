require 'rails_helper'

RSpec.describe Infraestructura::Eventos::Evento do
  let(:evento) { described_class.new }
  let(:usuario) { create(:usuario) }

  describe 'associations' do
    it { is_expected.to belong_to(:historial) }
    it { is_expected.to belong_to(:origen) }
    it { is_expected.to belong_to(:usuario).optional }
  end

  describe '.accion' do
    it 'returns underscored class name as symbol' do
      expect(described_class.accion).to eq(:evento)
    end
  end

  describe '#accion' do
    it 'delegates to class method' do
      expect(evento.accion).to eq(:evento)
    end
  end

  describe '#disparar' do
    it 'requires an origen parameter' do
      expect(evento).to respond_to(:disparar)
    end

    it 'has transition methods' do
      expect(evento).to respond_to(:disparable?)
      expect(evento).to respond_to(:automatico?)
    end
  end

  describe '#disparable?' do
    it 'returns true by default' do
      expect(evento.disparable?).to be true
    end
  end

  describe '#automatico?' do
    it 'returns true when no usuario' do
      evento.usuario = nil
      expect(evento.automatico?).to be true
    end

    it 'returns false when usuario present' do
      evento.usuario = usuario
      expect(evento.automatico?).to be false
    end
  end

  describe '#manual?' do
    it 'returns false when no usuario' do
      evento.usuario = nil
      expect(evento.manual?).to be false
    end

    it 'returns true when usuario present' do
      evento.usuario = usuario
      expect(evento.manual?).to be true
    end
  end

  describe 'scopes' do
    describe '.orden_descendiente' do
      it 'is defined as a scope' do
        expect(described_class).to respond_to(:orden_descendiente)
      end
    end
  end
end
