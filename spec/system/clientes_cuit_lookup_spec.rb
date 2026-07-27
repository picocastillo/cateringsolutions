require 'rails_helper'

# Step 9 follow-up: end-to-end browser coverage of the search-first CUIT
# lookup + vincular flow on the new-cliente page. Admins must look up a CUIT
# before the rest of the form is revealed; if a cliente with that CUIT already
# exists anywhere in the system the page offers to vincular instead of
# creating a duplicate row.
RSpec.describe 'Clientes new-form CUIT lookup', :js, type: :system do
  let!(:tienda_a) { create(:tienda, nombre: 'Tienda A', dominio: 'a.example.com') }
  let!(:tienda_b) { create(:tienda, nombre: 'Tienda B', dominio: 'b.example.com') }

  let!(:admin) do
    create(:usuario, :admin,
           nombre: 'Admin Cuit',
           login: 'cuitadmin',
           password: 'cuit123',
           password_confirmation: 'cuit123',
           visualizando_tienda: tienda_a).tap do |u|
      u.tiendas << tienda_a unless u.tiendas.include?(tienda_a)
    end
  end

  def login_as_admin
    visit root_path
    fill_in 'username', with: admin.login
    fill_in 'password', with: 'cuit123'
    click_button 'Iniciar sesión'
    expect(page).to have_current_path('/inicio', wait: 5)
  end

  def buscar_cuit(value)
    fill_in 'cuit-buscar-input', with: value
    click_button 'Buscar o Crear'
  end

  context 'when CUIT does not exist anywhere' do
    it 'reveals the form and lets the admin create a new cliente' do
      login_as_admin
      visit new_cliente_path

      # Cliente form is hidden initially — the cuit search panel is the only
      # interactive element.
      expect(page).not_to have_field('cliente_nombre', visible: true)

      buscar_cuit('20294834487')

      expect(page).to have_field('cliente_nombre', visible: true, wait: 5)
      expect(page).to have_content('CUIT disponible')

      # The form's CUIT input is prefilled with the searched value.
      expect(find('#cliente_cuit', visible: :all).value).to eq('20294834487')

      fill_in 'cliente_nombre', with: 'Cliente Nuevo'
      click_button 'Crear'

      expect(page).to have_content('creado correctamente', wait: 5)
      expect(Clientes::Cliente.where(cuit: '20294834487').count).to eq(1)
      expect(Clientes::Cliente.find_by(cuit: '20294834487').tiendas).to contain_exactly(tienda_a)
    end
  end

  context 'when CUIT exists in another tienda (cross-tienda duplicate)' do
    let!(:existing) do
      create(:cliente, nombre: 'Sancor Salud', cuit: '20294834487', tiendas: [tienda_b])
    end

    it 'offers to vincular and on accept lands on the existing cliente edit page' do
      login_as_admin
      visit new_cliente_path

      accept_confirm(/Sancor Salud.*otra tienda.*Tienda B/m) do
        buscar_cuit('20294834487')
      end

      expect(page).to have_current_path(edit_cliente_path(existing), wait: 10)
      expect(page).to have_content('Sancor Salud')
      expect(existing.reload.tiendas).to contain_exactly(tienda_a, tienda_b)
    end

    it 'does NOT vincular when admin dismisses the confirm dialog' do
      login_as_admin
      visit new_cliente_path

      dismiss_confirm do
        buscar_cuit('20294834487')
      end

      expect(page).to have_current_path(new_cliente_path)
      expect(page).not_to have_field('cliente_nombre', visible: true)
      expect(existing.reload.tiendas).to contain_exactly(tienda_b)
    end

    it 'normalizes formatted CUIT input (handles dashes)' do
      login_as_admin
      visit new_cliente_path

      accept_confirm(/Sancor Salud/) do
        buscar_cuit('20-29483448-7')
      end

      expect(page).to have_current_path(edit_cliente_path(existing), wait: 10)
      expect(existing.reload.tiendas).to contain_exactly(tienda_a, tienda_b)
    end
  end

  context 'when CUIT belongs to a cliente already linked to current tienda' do
    let!(:existing) do
      create(:cliente, nombre: 'Acme Local', cuit: '20294834487', tiendas: [tienda_a])
    end

    it 'offers to edit instead of vincular' do
      login_as_admin
      visit new_cliente_path

      accept_confirm(/ya existe.*Acme Local.*esta tienda/im) do
        buscar_cuit('20294834487')
      end

      expect(page).to have_current_path(edit_cliente_path(existing), wait: 10)
      expect(existing.reload.tiendas).to contain_exactly(tienda_a)
    end

    it 'stays on the new form when admin dismisses' do
      login_as_admin
      visit new_cliente_path

      dismiss_confirm do
        buscar_cuit('20294834487')
      end

      expect(page).to have_current_path(new_cliente_path)
      expect(page).not_to have_field('cliente_nombre', visible: true)
    end
  end

  context 'when CUIT is incomplete' do
    it 'shows an error and keeps the form hidden' do
      login_as_admin
      visit new_cliente_path

      buscar_cuit('20294834')

      expect(page).to have_content('11 dígitos')
      expect(page).not_to have_field('cliente_nombre', visible: true)
    end
  end
end
