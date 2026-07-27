require 'rails_helper'

RSpec.describe 'Inicio - QZ Tray & Ayuda', type: :request do
  let(:tienda) { create(:tienda, nombre: 'Tienda QZ Test', carrito_de_compras: true, dominio: 'www.example.com') }
  let(:admin_user) do
    u = create(:usuario, :admin, visualizando_tienda: tienda)
    u.tiendas << tienda unless u.tiendas.include?(tienda)
    u
  end
  let(:cliente_user) do
    cliente = create(:cliente, tienda: tienda)
    cuenta = create(:cuenta, cliente: cliente)
    create(:usuario, :cliente, visualizando_tienda: tienda, cuenta: cuenta)
  end

  describe 'GET /ayuda' do
    context 'as admin' do
      before { login_as(admin_user) }

      it 'renders the ayuda page with the printer tutorial' do
        get '/ayuda'
        expect(response).to have_http_status(:ok)
        expect(response.body).to include('Configurar Impresión Automática de Tickets (QZ Tray)')
        expect(response.body).to include('tutorial-impresora')
        expect(response.body).to include('Descargar QZ Tray')
        expect(response.body).to include('Probar Impresora')
      end

      it 'renders the body tag with data-servicio-impresion attribute' do
        get '/ayuda'
        expect(response.body).to match(/data-servicio-impresion="whb"/)
      end

      it 'renders data-servicio-impresion=qztray when user switches' do
        admin_user.update_column(:servicio_de_impresion_id, 2)
        get '/ayuda'
        expect(response.body).to match(/data-servicio-impresion="qztray"/)
      end
    end

    context 'as cliente' do
      before { login_as(cliente_user) }

      it 'renders the ayuda page without the printer tutorial' do
        get '/ayuda'
        expect(response).to have_http_status(:ok)
        expect(response.body).not_to include('tutorial-impresora')
        expect(response.body).not_to include('Configurar Impresión Automática de Tickets (QZ Tray)')
      end

      it 'does not render data-servicio-impresion attribute' do
        get '/ayuda'
        expect(response.body).not_to include('data-servicio-impresion')
      end
    end
  end

  describe 'GET /qz_certificate' do
    before { login_as(admin_user) }

    it 'returns the certificate file' do
      get '/qz_certificate'
      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include('text/plain')
      expect(response.body).to include('BEGIN CERTIFICATE')
    end

    it 'returns 404 when certificate file is missing' do
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with(Rails.root.join('config/qz_tray/digital-certificate.txt')).and_return(false)

      get '/qz_certificate'
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST /qz_sign' do
    before { login_as(admin_user) }

    it 'signs the request data and returns base64 signature' do
      post '/qz_sign', params: { request: 'test-message-to-sign' }

      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include('text/plain')

      # Verify the signature is valid base64
      signature = response.body
      expect { Base64.strict_decode64(signature) }.not_to raise_error

      # Verify the signature can be verified with the public cert
      cert_path = Rails.root.join('config/qz_tray/digital-certificate.txt')
      if File.exist?(cert_path)
        cert = OpenSSL::X509::Certificate.new(File.read(cert_path))
        decoded_sig = Base64.strict_decode64(signature)
        verified = cert.public_key.verify(OpenSSL::Digest.new('SHA512'), decoded_sig, 'test-message-to-sign')
        expect(verified).to be true
      end
    end

    it 'returns 404 when private key is missing' do
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with(Rails.root.join('config/qz_tray/private-key.pem')).and_return(false)

      post '/qz_sign', params: { request: 'test-message' }
      expect(response).to have_http_status(:not_found)
    end

    it 'handles empty request parameter' do
      post '/qz_sign', params: { request: '' }
      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include('text/plain')
    end
  end

  describe 'GET /ayuda/test_print' do
    context 'as admin' do
      before { login_as(admin_user) }

      it 'returns a PDF' do
        get '/ayuda/test_print', params: { format: :pdf }
        expect(response).to have_http_status(:ok)
      end
    end

    context 'as cliente' do
      before { login_as(cliente_user) }

      it 'returns forbidden' do
        get '/ayuda/test_print', params: { format: :pdf }
        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
