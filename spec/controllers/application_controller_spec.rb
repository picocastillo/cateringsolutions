require 'rails_helper'

RSpec.describe ApplicationController, type: :controller do
  let(:user) { create(:usuario) }
  let(:tienda) { create(:tienda) }

  controller do
    skip_authorization_check
    skip_before_action :login_required
    skip_before_action :password_not_expired_required
    skip_before_action :load_pedidos_cocina

    def test_action
      render plain: 'OK'
    end
  end

  before do
    routes.draw { get 'test_action' => 'anonymous#test_action' }
    allow(controller).to receive_messages(current_user: user, tienda_activa: tienda)
  end

  describe '#filtered_params' do
    it 'excludes commit, utf8, action, controller, format' do
      get :test_action, params: { commit: 'Save', utf8: '✓', test: 'value' }
      result = controller.send(:filtered_params)
      expect(result).not_to have_key(:commit)
      expect(result).not_to have_key(:utf8)
      expect(result).not_to have_key(:action)
      expect(result).not_to have_key(:controller)
    end

    it 'includes other params' do
      get :test_action, params: { test: 'value', search: 'query' }
      result = controller.send(:filtered_params)
      expect(result[:test]).to eq('value')
      expect(result[:search]).to eq('query')
    end
  end

  describe 'before actions' do
    it 'disables browser caching' do
      get :test_action
      expect(response.headers['Cache-Control']).to include('no-store')
    end

    it 'has login_required before_action configured' do
      expect(described_class._process_action_callbacks.map(&:filter)).to include(:login_required)
    end
  end

  describe 'error handling' do
    it 'rescues CanCan::AccessDenied' do
      allow(controller).to receive(:test_action).and_raise(
        CanCan::AccessDenied.new('Not authorized', :read, Object)
      )
      allow(controller).to receive(:show_error)
      get :test_action
      expect(controller).to have_received(:show_error)
    end

    it 'rescues Timeout::Error' do
      allow(controller).to receive(:test_action).and_raise(Timeout::Error)
      allow(controller).to receive(:show_error)
      get :test_action
      expect(controller).to have_received(:show_error)
    end
  end
end
