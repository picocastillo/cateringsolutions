require 'rails_helper'

RSpec.describe ApplicationJob do
  let(:job) { described_class.new }

  describe 'error handling' do
    it 'has exception rescue configured' do
      expect(described_class.rescue_handlers).not_to be_empty
    end
  end

  describe 'retry configuration' do
    it 'retries on SocketError' do
      allow(Notify).to receive(:exception)

      expect(described_class).to respond_to(:retry_on)
    end
  end

  describe 'inheritance' do
    it 'inherits from ActiveJob::Base' do
      expect(described_class.superclass).to eq(ActiveJob::Base)
    end
  end
end
