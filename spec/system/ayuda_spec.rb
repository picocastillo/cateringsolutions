require 'rails_helper'

RSpec.describe 'Ayuda - Printer Tutorial', :js, type: :system do
  let(:tienda) { create(:tienda, nombre: 'Tienda Ayuda Test', carrito_de_compras: true, video_ayuda: 'https://www.youtube.com/embed/test') }
  let(:admin) { create(:usuario, :admin, :with_password, visualizando_tienda: tienda) }

  before do
    admin.tiendas << tienda unless admin.tiendas.include?(tienda)
  end

  describe 'admin user' do
    before do
      admin_login(admin, 'password123')
    end

    it 'sees the printer tutorial card on the ayuda page' do
      visit '/ayuda'

      expect(page).to have_css('#tutorial-impresora', visible: :hidden)
      expect(page).to have_content('Configurar Impresión Automática de Tickets (QZ Tray)')
    end

    it 'expands the tutorial accordion to see installation steps' do
      visit '/ayuda'

      # Click the header to expand
      find('[data-target="#tutorial-impresora"]').click

      # Wait for animation and check content is visible
      expect(page).to have_css('#tutorial-impresora.show', wait: 5)
      expect(page).to have_content('Instalar Java')
      expect(page).to have_content('Descargar QZ Tray')
      expect(page).to have_content('Instalar el programa')
      expect(page).to have_content('Copiar el certificado de seguridad')
      expect(page).to have_content('Activar QZ Tray en tu cuenta')
      expect(page).to have_content('Probar la impresora')
    end

    it 'shows a download link for QZ Tray' do
      visit '/ayuda'
      find('[data-target="#tutorial-impresora"]').click
      expect(page).to have_css('#tutorial-impresora.show', wait: 5)

      expect(page).to have_link('Descargar QZ Tray (gratis)', href: 'https://qz.io/download/')
    end

    it 'shows a download link for the security certificate' do
      visit '/ayuda'
      find('[data-target="#tutorial-impresora"]').click
      expect(page).to have_css('#tutorial-impresora.show', wait: 5)

      expect(page).to have_link('Descargar certificado', href: '/qz_certificate')
    end

    it 'shows the test print button with silentprint class' do
      visit '/ayuda'
      find('[data-target="#tutorial-impresora"]').click
      expect(page).to have_css('#tutorial-impresora.show', wait: 5)

      test_btn = find('#test-print-btn')
      expect(test_btn[:class]).to include('silentprint')
      expect(test_btn[:href]).to end_with('/ayuda/test_print.pdf')
    end

    it 'has the silentPrint JavaScript function available' do
      visit '/ayuda'
      result = page.evaluate_script('typeof window.silentPrint')
      expect(result).to eq('function')
    end

    it 'has the printService object available' do
      visit '/ayuda'
      result = page.evaluate_script('typeof window.printService')
      expect(result).to eq('object')
    end

    it 'has the printService.connect method available' do
      visit '/ayuda'
      result = page.evaluate_script('typeof window.printService.connect')
      expect(result).to eq('function')
    end

    it 'renders the body with data-servicio-impresion attribute' do
      visit '/ayuda'
      expect(page).to have_css('body[data-servicio-impresion]')
    end

    it 'defaults to WHB print service' do
      visit '/ayuda'
      servicio = page.evaluate_script("document.body.getAttribute('data-servicio-impresion')")
      expect(servicio).to eq('whb')
    end

    it 'uses QZ Tray print service when user has qztray setting' do
      admin.update_column(:servicio_de_impresion_id, 2)
      visit '/ayuda'
      servicio = page.evaluate_script("document.body.getAttribute('data-servicio-impresion')")
      expect(servicio).to eq('qztray')
    end
  end

  describe 'cliente user' do
    let(:cliente) { create(:cliente, tienda: tienda) }
    let(:cuenta) { create(:cuenta, cliente: cliente) }
    let(:cliente_user) { create(:usuario, :cliente, :with_password, visualizando_tienda: tienda, cuenta: cuenta) }

    before do
      cliente_user.tiendas << tienda unless cliente_user.tiendas.include?(tienda)
    end

    it 'does not see the printer tutorial card' do
      user_login(cliente_user, 'password123')
      visit '/ayuda'

      expect(page).not_to have_css('#tutorial-impresora', visible: :all)
      expect(page).not_to have_content('Configurar Impresión Automática de Tickets (QZ Tray)')
    end
  end
end
