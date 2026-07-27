require 'rails_helper'

RSpec.describe ApplicationMailer, type: :mailer do
  describe 'configuration' do
    it 'has default from address' do
      expect(described_class.default[:from]).to eq 'from@example.com'
    end

    it 'uses mailer layout' do
      expect(described_class._layout).to eq 'mailer'
    end
  end

  describe '#notificacion_excepcion' do
    let(:subject_text) { 'Test Exception' }
    let(:body_text) { 'This is a test exception message' }
    let(:mail) { described_class.notificacion_excepcion(subject_text, body_text) }

    it 'sends to correct email' do
      expect(mail.to).to eq ['sebachavarini@gmail.com']
    end

    it 'has correct subject' do
      expect(mail.subject).to eq subject_text
    end

    it 'has correct body' do
      expect(mail.body.encoded).to include body_text
    end

    it 'sends from default address' do
      expect(mail.from).to eq ['from@example.com']
    end
  end
end
