require 'rails_helper'

RSpec.describe 'Admin tienda switcher', :js, type: :system do
  before do
    @tienda_a = create(:tienda, nombre: 'Tienda Alfa', dominio: 'localhost')
    @tienda_b = create(:tienda, nombre: 'Tienda Beta', dominio: 'localhost')

    @admin = create(:usuario, :admin,
                    login: 'switcher_admin',
                    password: 'admin123',
                    password_confirmation: 'admin123',
                    visualizando_tienda: @tienda_a)
    @admin.tiendas << @tienda_a unless @admin.tiendas.include?(@tienda_a)
    @admin.tiendas << @tienda_b unless @admin.tiendas.include?(@tienda_b)
  end

  def login_admin
    visit root_path
    fill_in 'username', with: @admin.login
    fill_in 'password', with: 'admin123'
    click_button 'Iniciar sesión'
    expect(page).to have_current_path('/inicio', wait: 10)
  end

  it 'changes the active tienda when admin clicks a tienda pill in the profile dropdown' do
    login_admin

    # Open the profile dropdown
    find('.dropdown-toggle', match: :first).click
    expect(page).to have_css('.tienda-switcher-btns', wait: 5)

    # Tienda Alfa should be active, Tienda Beta should not
    within('.tienda-switcher-btns') do
      expect(page).to have_css('.btn-tienda-pill.activa', text: 'T.A')
      expect(page).not_to have_css('.btn-tienda-pill.activa', text: 'T.B')
    end

    # Set a JS navigation marker so we can detect when the page reloads
    page.execute_script('window._preSwitchMarker = true')

    # Click Tienda Beta's pill
    within('.tienda-switcher-btns') do
      find('.btn-tienda-switch', text: 'T.B').click
    end

    # Wait for the AJAX to complete (jQuery.active drops to 0 after response received)
    wait_for_ajax

    # Wait for the page to reload (window._preSwitchMarker disappears after a full page reload)
    Timeout.timeout(15) do
      loop do
        break if page.evaluate_script('typeof window._preSwitchMarker') == 'undefined'

        sleep 0.2
      end
    end

    # Verify the tienda actually changed in the database
    expect(@admin.reload.visualizando_tienda_id).to eq(@tienda_b.id)

    # Open dropdown again and verify Tienda Beta is now active
    find('.dropdown-toggle', match: :first, wait: 10).click
    within('.tienda-switcher-btns', wait: 10) do
      expect(page).to have_css('.btn-tienda-pill.activa', text: 'T.B', wait: 10)
      expect(page).not_to have_css('.btn-tienda-pill.activa', text: 'T.A', wait: 5)
    end
  end
end
