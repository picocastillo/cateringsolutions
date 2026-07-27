require 'rails_helper'

RSpec.describe Infraestructura::Documento, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:documentable).optional }
    it { is_expected.to belong_to(:autor).class_name('Usuarios::Usuario') }
  end

  describe 'acts_as_list' do
    it 'has position column' do
      documento = described_class.new
      expect(documento).to respond_to(:position)
    end
  end

  describe 'paperclip attachment' do
    it 'has documento attachment' do
      expect(described_class.attachment_definitions.keys).to include(:documento)
    end
  end

  describe 'delegations' do
    let(:documento) { described_class.new }

    it 'delegates url to documento attachment' do
      expect(documento).to respond_to(:url)
    end

    it 'delegates present? to documento attachment' do
      expect(documento).to respond_to(:present?)
    end

    it 'delegates exists? to documento attachment' do
      expect(documento).to respond_to(:exists?)
    end
  end

  describe 'instance methods' do
    describe '#image?' do
      it 'returns true for image content types' do
        documento = described_class.new(documento_content_type: 'image/jpeg')
        expect(documento.image?).to be true
      end

      it 'returns true for png images' do
        documento = described_class.new(documento_content_type: 'image/png')
        expect(documento.image?).to be true
      end

      it 'returns false for non-image content types' do
        documento = described_class.new(documento_content_type: 'application/pdf')
        expect(documento.image?).to be false
      end

      it 'returns false for nil content type' do
        documento = described_class.new(documento_content_type: nil)
        expect(documento.image?).to be false
      end
    end

    describe '#to_s' do
      it 'returns documento_file_name' do
        documento = described_class.new(documento_file_name: 'test_file.pdf')
        expect(documento.to_s).to eq 'test_file.pdf'
      end
    end
  end
end
