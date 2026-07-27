require 'rails_helper'

RSpec.describe LinksHelper, type: :helper do
  before do
    allow(helper).to receive(:can?).and_return(true)
  end

  describe '#show_link' do
    it 'returns nil when object is nil' do
      expect(helper.show_link(nil)).to be_nil
    end
  end

  describe '#destroy_link' do
    it 'responds to destroy_link' do
      expect(helper).to respond_to(:destroy_link)
    end
  end

  describe '#create_link' do
    it 'returns link for class' do
      allow(helper).to receive(:new_polymorphic_path).and_return('/new')
      result = helper.create_link(String, 'Create')
      expect(result).to include('Create')
    end
  end

  describe '#solo_hora' do
    it 'returns formatted time' do
      time = Time.zone.parse('2024-01-01 14:30:00')
      allow(time).to receive(:to_s).with(:short_time).and_return('14:30')
      expect(helper.solo_hora(time)).to eq('14:30')
    end

    it 'returns nil for nil' do
      expect(helper.solo_hora(nil)).to be_nil
    end
  end

  describe '#link_to_function' do
    it 'creates link with javascript void' do
      result = helper.link_to_function('Click me', class: 'btn')
      expect(result).to include('href')
      expect(result).to include('Click me')
    end
  end

  describe '#import_link' do
    it 'creates import link when authorized' do
      result = helper.import_link(String)
      expect(result).to include('Importar')
    end

    it 'returns nil when not authorized' do
      allow(helper).to receive(:can?).and_return(false)
      expect(helper.import_link(String)).to be_nil
    end
  end

  describe '#link_to_favorito' do
    it 'creates favorito link' do
      allow(helper).to receive(:icono_favorito).and_return('<i></i>'.html_safe)
      result = helper.link_to_favorito(true, '/path')
      expect(result).to be_present
    end
  end

  describe '#icono_favorito' do
    it 'returns filled star for favorito' do
      result = helper.icono_favorito(true)
      expect(result).to include('fa-star')
      expect(result).not_to include('fa-star-o')
    end

    it 'returns empty star for non-favorito' do
      result = helper.icono_favorito(false)
      expect(result).to include('fa-star-o')
    end
  end

  describe '#etiqueta_activo' do
    it 'returns success label for active with activo' do
      object = double('Object', activo: true, activo?: true)
      allow(object).to receive(:respond_to?).with(:activo).and_return(true)
      allow(object).to receive(:respond_to?).with(:activo?).and_return(true)
      allow(true).to receive(:to_sino).and_return('Si')

      result = helper.etiqueta_activo(object)
      expect(result).to include('label-success')
    end

    it 'returns danger label for inactive with active' do
      object = double('Object', active: false, active?: false)
      allow(object).to receive(:respond_to?).with(:activo).and_return(false)
      allow(object).to receive(:respond_to?).with(:activo?).and_return(false)
      allow(false).to receive(:to_sino).and_return('No')

      result = helper.etiqueta_activo(object)
      expect(result).to include('label-danger')
    end
  end
end
