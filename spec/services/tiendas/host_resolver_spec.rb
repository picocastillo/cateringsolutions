# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Tiendas::HostResolver do
  let!(:catering) { create(:tienda, nombre: 'Catering Solutions', dominio: 'cateringsolutions.com.ar') }
  let!(:tivoglio) { create(:tienda, nombre: 'Ti Voglio', dominio: 'tivoglio.com.ar') }

  before { described_class.reset_aliases! }
  after { described_class.reset_aliases! }

  describe '.normalize' do
    it 'strips www and downcases' do
      expect(described_class.normalize('WWW.CateringSolutions.com.ar')).to eq('cateringsolutions.com.ar')
    end
  end

  describe '.canonical_dominio' do
    it 'returns apex domain for production hosts' do
      expect(described_class.canonical_dominio('www.cateringsolutions.com.ar')).to eq('cateringsolutions.com.ar')
      expect(described_class.canonical_dominio('tivoglio.com.ar')).to eq('tivoglio.com.ar')
    end

    it 'maps trackerdev hosts via aliases' do
      expect(described_class.canonical_dominio('cateringsolutions.trackerdev.com.ar'))
        .to eq('cateringsolutions.com.ar')
      expect(described_class.canonical_dominio('www.tivoglio.trackerdev.com.ar'))
        .to eq('tivoglio.com.ar')
    end
  end

  describe '.matches?' do
    it 'matches production apex and www' do
      expect(described_class.matches?('cateringsolutions.com.ar', catering.dominio)).to be(true)
      expect(described_class.matches?('www.tivoglio.com.ar', tivoglio.dominio)).to be(true)
    end

    it 'matches trackerdev aliases without changing tiendas.dominio' do
      expect(described_class.matches?('cateringsolutions.trackerdev.com.ar', catering.dominio)).to be(true)
      expect(described_class.matches?('tivoglio.trackerdev.com.ar', tivoglio.dominio)).to be(true)
      expect(described_class.matches?('cateringsolutions.trackerdev.com.ar', tivoglio.dominio)).to be(false)
    end
  end

  describe '.find_tienda' do
    it 'finds by production domain' do
      expect(described_class.find_tienda('www.cateringsolutions.com.ar')).to eq(catering)
      expect(described_class.find_tienda('tivoglio.com.ar')).to eq(tivoglio)
    end

    it 'finds by trackerdev host using aliases' do
      expect(described_class.find_tienda('cateringsolutions.trackerdev.com.ar')).to eq(catering)
      expect(described_class.find_tienda('www.tivoglio.trackerdev.com.ar')).to eq(tivoglio)
    end
  end

  describe '.public_host' do
    it 'keeps the staging request host when it maps to the tienda' do
      expect(
        described_class.public_host('cateringsolutions.trackerdev.com.ar', catering.dominio)
      ).to eq('cateringsolutions.trackerdev.com.ar')
    end

    it 'falls back to tienda dominio when host does not match' do
      expect(
        described_class.public_host('other.example.com', catering.dominio)
      ).to eq('cateringsolutions.com.ar')
    end
  end
end
