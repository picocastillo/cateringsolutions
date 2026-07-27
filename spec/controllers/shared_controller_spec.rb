require 'rails_helper'

RSpec.describe SharedController, type: :controller do
  describe 'helper methods' do
    it 'defines current_user helper' do
      expect(described_class._helper_methods).to include(:current_user)
    end

    it 'defines tienda_activa helper' do
      expect(described_class._helper_methods).to include(:tienda_activa)
    end
  end

  describe 'error handling' do
    it 'rescues ErrorAplicacion' do
      handler_names = described_class.rescue_handlers.map { |h| h.first.to_s }
      expect(handler_names).to include('ErrorAplicacion')
    end

    it 'rescues InvalidQuery' do
      handler_names = described_class.rescue_handlers.map { |h| h.first.to_s }
      expect(handler_names).to include('InvalidQuery')
    end
  end
end
