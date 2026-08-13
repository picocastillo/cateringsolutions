require 'rails_helper'

RSpec.describe 'MODO_PRUEBA site banner', type: :request do
  let(:tienda) { create(:tienda, dominio: 'www.example.com') }
  let(:admin_user) do
    u = create(:usuario, :admin, visualizando_tienda: tienda)
    u.tiendas << tienda unless u.tiendas.include?(tienda)
    u
  end

  around do |example|
    original = ENV.fetch('MODO_PRUEBA', nil)
    begin
      example.run
    ensure
      if original.nil?
        ENV.delete('MODO_PRUEBA')
      else
        ENV['MODO_PRUEBA'] = original
      end
    end
  end

  def expect_banner
    expect(response.body).to include('id="modo-prueba-banner"')
    expect(response.body).to include('MODO PRUEBA')
    expect(response.body).to match(/class="[^"]*\bmodo-prueba\b/)
  end

  def expect_no_banner
    expect(response.body).not_to include('id="modo-prueba-banner"')
    expect(response.body).not_to match(/class="[^"]*\bmodo-prueba\b/)
  end

  context 'when MODO_PRUEBA=true' do
    before { ENV['MODO_PRUEBA'] = 'true' }

    it 'shows the banner on logged-in pages' do
      login_as(admin_user)
      get '/ayuda'
      expect(response).to have_http_status(:ok)
      expect_banner
    end

    it 'shows the banner on the public login page' do
      host! tienda.dominio
      get '/'
      expect(response).to have_http_status(:ok)
      expect_banner
    end
  end

  context 'when MODO_PRUEBA is unset' do
    before { ENV.delete('MODO_PRUEBA') }

    it 'does not show the banner on logged-in pages' do
      login_as(admin_user)
      get '/ayuda'
      expect(response).to have_http_status(:ok)
      expect_no_banner
    end

    it 'does not show the banner on the public login page' do
      host! tienda.dominio
      get '/'
      expect(response).to have_http_status(:ok)
      expect_no_banner
    end
  end
end
