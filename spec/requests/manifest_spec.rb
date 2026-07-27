require 'rails_helper'

RSpec.describe 'Dynamic manifest.json', type: :request do
  # response.parsed_body doesn't handle application/manifest+json content type,
  # so we must use JSON.parse directly.
  def parse_manifest
    JSON.parse(response.body) # rubocop:disable Rails/ResponseParsedBody
  end

  let!(:tienda_cs) do
    create(:tienda, nombre: 'Catering Solutions', dominio: 'cateringsolutions.com.ar',
                    color_de_fondo: '#fbfbfb', color_barra_superior: '#f2f2f2')
  end
  let!(:tienda_tv) do
    create(:tienda, nombre: 'Ti Voglio La Tienda', dominio: 'tivoglio.com.ar',
                    color_de_fondo: '#ffffff', color_barra_superior: '#333333')
  end

  before do
    # Manifest is public (no login required), so we stub tienda_activa directly
    allow_any_instance_of(PublicsController).to receive(:login_required).and_return(true)
  end

  describe 'GET /manifest.json' do
    it 'returns valid JSON with correct content type' do
      allow_any_instance_of(PublicsController).to receive(:tienda_activa).and_return(tienda_cs)
      get '/manifest.json'

      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include('application/manifest+json')
      expect { parse_manifest }.not_to raise_error
    end

    context 'for Catering Solutions tienda' do
      before do
        allow_any_instance_of(PublicsController).to receive(:tienda_activa).and_return(tienda_cs)
        get '/manifest.json'
        @manifest = parse_manifest
      end

      it 'uses tienda nombre' do
        expect(@manifest['name']).to eq('Catering Solutions')
        expect(@manifest['short_name']).to eq('Catering Sol')
      end

      it 'uses tienda colors' do
        expect(@manifest['background_color']).to eq('#fbfbfb')
        expect(@manifest['theme_color']).to eq('#f2f2f2')
      end

      it 'uses dominio-prefixed icon paths' do
        icon_srcs = @manifest['icons'].map { |i| i['src'] } # rubocop:disable Rails/Pluck
        expect(icon_srcs).to include('/cateringsolutions.com.ar_launcher-icon-1x.png')
        expect(icon_srcs).to include('/cateringsolutions.com.ar_launcher-icon-2x.png')
        expect(icon_srcs).to include('/cateringsolutions.com.ar_launcher-icon-4x.png')
        expect(icon_srcs).to include('/cateringsolutions.com.ar_launcher-icon-5x.png')
      end

      it 'uses dominio-prefixed screenshot paths' do
        screenshot_srcs = @manifest['screenshots'].map { |i| i['src'] } # rubocop:disable Rails/Pluck
        expect(screenshot_srcs).to include('/cateringsolutions.com.ar_screenshot1.png')
        expect(screenshot_srcs).to include('/cateringsolutions.com.ar_screenshot2.png')
      end

      it 'uses dominio-prefixed shortcut icon paths' do
        shortcut_icons = @manifest['shortcuts'].flat_map { |s| s['icons'].map { |i| i['src'] } }
        expect(shortcut_icons).to all(start_with('/cateringsolutions.com.ar_'))
      end

      it 'includes standard PWA fields' do
        expect(@manifest['display']).to eq('standalone')
        expect(@manifest['start_url']).to eq('/')
      end
    end

    context 'for Ti Voglio tienda' do
      before do
        allow_any_instance_of(PublicsController).to receive(:tienda_activa).and_return(tienda_tv)
        get '/manifest.json'
        @manifest = parse_manifest
      end

      it 'uses Ti Voglio nombre' do
        expect(@manifest['name']).to eq('Ti Voglio La Tienda')
      end

      it 'uses Ti Voglio colors' do
        expect(@manifest['background_color']).to eq('#ffffff')
        expect(@manifest['theme_color']).to eq('#333333')
      end

      it 'uses tivoglio dominio-prefixed icon paths' do
        icon_srcs = @manifest['icons'].map { |i| i['src'] } # rubocop:disable Rails/Pluck
        expect(icon_srcs).to include('/tivoglio.com.ar_launcher-icon-4x.png')
      end
    end

    context 'for tienda without dominio' do
      let!(:tienda_no_dominio) do
        create(:tienda, nombre: 'Sin Dominio', dominio: nil,
                        color_de_fondo: nil, color_barra_superior: nil)
      end

      before do
        allow_any_instance_of(PublicsController).to receive(:tienda_activa).and_return(tienda_no_dominio)
        get '/manifest.json'
        @manifest = parse_manifest
      end

      it 'falls back to cateringsolutions.com.ar for icon paths' do
        icon_srcs = @manifest['icons'].map { |i| i['src'] } # rubocop:disable Rails/Pluck
        expect(icon_srcs).to include('/cateringsolutions.com.ar_launcher-icon-4x.png')
      end

      it 'falls back to default colors' do
        expect(@manifest['background_color']).to eq('#686877')
        expect(@manifest['theme_color']).to eq('#232323')
      end
    end

    it 'does not require authentication' do
      # Remove the login stub to test truly unauthenticated
      allow_any_instance_of(PublicsController).to receive(:login_required).and_call_original
      allow_any_instance_of(PublicsController).to receive(:tienda_activa).and_return(tienda_cs)
      get '/manifest.json'

      expect(response).to have_http_status(:ok)
    end
  end
end
