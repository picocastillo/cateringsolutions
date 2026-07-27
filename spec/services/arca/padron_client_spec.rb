require 'rails_helper'

RSpec.describe Arca::PadronClient do
  let(:ws_double) { instance_double(Afipws::WSConstanciaInscripcion) }

  before do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:[]).with('AFIP_CUIT').and_return('20123456789')
    allow(ENV).to receive(:[]).with('AFIP_KEY').and_return('key-content')
    allow(ENV).to receive(:[]).with('AFIP_CERT').and_return('cert-content')
    allow(Afipws::WSConstanciaInscripcion).to receive(:new).and_return(ws_double)
  end

  describe '.fetch' do
    it 'returns nil for malformed CUITs' do
      expect(described_class.fetch('123')).to be_nil
      expect(described_class.fetch(nil)).to be_nil
    end

    it 'returns nil when any credential ENV var is missing' do
      allow(ENV).to receive(:[]).with('AFIP_CUIT').and_return(nil)
      expect(described_class.fetch('20294834487')).to be_nil
    end

    it 'normalizes a JURIDICA response' do
      allow(ws_double).to receive(:get_persona).and_return(
        datos_generales: {
          razon_social: 'LA REGALERIA SA',
          tipo_persona: 'JURIDICA',
          estado_clave: 'ACTIVO',
          domicilio_fiscal: {
            direccion: 'AV SIEMPRE VIVA 742',
            localidad: 'Springfield',
            descripcion_provincia: 'Buenos Aires',
            cod_postal: '1414'
          }
        }
      )

      result = described_class.fetch('20294834487')

      expect(result).to include(
        nombre: 'LA REGALERIA SA',
        domicilio: 'AV SIEMPRE VIVA 742, Springfield, Buenos Aires (1414)',
        tipo_persona: 'JURIDICA',
        estado: 'ACTIVO'
      )
    end

    it 'normalizes a FISICA response (apellido + nombre)' do
      allow(ws_double).to receive(:get_persona).and_return(
        datos_generales: {
          apellido: 'Pérez', nombre: 'Juan',
          tipo_persona: 'FISICA', estado_clave: 'ACTIVO',
          domicilio_fiscal: { direccion: 'Calle 1 100', localidad: 'CABA' }
        }
      )

      result = described_class.fetch('20294834487')

      expect(result[:nombre]).to eq('Pérez Juan')
      expect(result[:domicilio]).to eq('Calle 1 100, CABA')
    end

    it 'returns nil on Afipws::Error' do
      allow(ws_double).to receive(:get_persona).and_raise(Afipws::Error, '602: Sin resultados')
      expect(described_class.fetch('20294834487')).to be_nil
    end

    it 'returns nil on network errors' do
      allow(ws_double).to receive(:get_persona).and_raise(Afipws::NetworkError)
      expect(described_class.fetch('20294834487')).to be_nil
    end
  end
end
