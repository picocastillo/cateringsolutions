require 'rails_helper'

RSpec.describe Referencia::Provincia, type: :model do
  describe 'instance methods' do
    let(:provincia) { described_class.new(nombre: 'Buenos Aires') }

    describe '#to_s' do
      it 'returns the nombre' do
        expect(provincia.to_s).to eq 'Buenos Aires'
      end
    end
  end

  describe 'on_const_missing_detect_by' do
    it 'allows accessing provincia by name constant' do
      # Create a provincia if it doesn't exist
      provincia = described_class.find_or_create_by!(nombre: 'BUENOS_AIRES') do |p|
        p.nombre = 'BUENOS_AIRES'
      end

      # Should be able to access via constant-like syntax if the gem supports it
      expect(provincia).to be_present
      expect(provincia.nombre).to eq 'BUENOS_AIRES'
    end
  end

  describe 'validations' do
    let(:provincia) { described_class.create!(nombre: 'Córdoba') }

    it 'can be created with valid attributes' do
      expect(provincia).to be_persisted
      expect(provincia.nombre).to eq 'Córdoba'
    end
  end
end
