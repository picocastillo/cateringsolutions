require 'rails_helper'

RSpec.describe 'Cupones Management', :js, type: :system do
  before do
    @tienda = create(:tienda, nombre: 'Test Store Cupones')
    @admin_user = create(:usuario, :admin,
                         nombre: 'Admin Cupones',
                         login: 'cuponadmin',
                         password: 'cup123',
                         password_confirmation: 'cup123',
                         visualizando_tienda: @tienda)
  end

  def login_as_admin
    visit root_path
    fill_in 'username', with: @admin_user.login
    fill_in 'password', with: 'cup123'
    click_button 'Iniciar sesión'
    expect(page).to have_current_path('/inicio', wait: 5)
  end

  context 'Cupones Index' do
    before do
      @cupon1 = create(:cupon, tienda: @tienda, tipo_descuento: 'importe', importe: 500)
      @cupon2 = create(:cupon, :porcentaje, tienda: @tienda, porcentaje: 15, limite_bonificacion: 2000)
    end

    it 'displays all cupones with their attributes' do
      login_as_admin
      visit '/cupones'

      expect(page).to have_content('Cupones')
      expect(page).to have_content(@cupon1.codigo)
      expect(page).to have_content(@cupon2.codigo)
      expect(page).to have_content('Importe Fijo')
      expect(page).to have_content('Porcentaje')
      expect(page).to have_css('.label-success', text: 'Vigente')
    end
  end

  context 'Creating a new Cupón' do
    it 'creates a cupon with importe fijo' do
      login_as_admin
      visit '/cupones'

      click_link 'Nuevo'

      within('.modal', wait: 10) do
        expect(page).to have_content('Nuevo Cupón')

        select 'Importe Fijo', from: 'cupon_tipo_descuento'
        fill_in 'cupon_importe', with: '1500'

        click_button 'Crear'
      end

      expect(page).not_to have_css('.modal', visible: true, wait: 5)

      cupon = Cupones::Cupon.last
      expect(cupon).to be_present
      expect(cupon.tipo_descuento).to eq('importe')
      expect(cupon.importe.to_f).to eq(1500.0)
      expect(cupon.codigo).to be_present
      expect(cupon.fecha_vencimiento).to be_present
    end

    it 'creates a cupon with porcentaje y limite' do
      login_as_admin
      visit '/cupones'

      click_link 'Nuevo'

      within('.modal', wait: 10) do
        select 'Porcentaje con Límite', from: 'cupon_tipo_descuento'
        fill_in 'cupon_porcentaje', with: '10'
        fill_in 'cupon_limite_bonificacion', with: '1000'

        click_button 'Crear'
      end

      expect(page).not_to have_css('.modal', visible: true, wait: 5)

      cupon = Cupones::Cupon.last
      expect(cupon).to be_present
      expect(cupon.tipo_descuento).to eq('porcentaje')
      expect(cupon.porcentaje.to_f).to eq(10.0)
      expect(cupon.limite_bonificacion.to_f).to eq(1000.0)
    end
  end

  context 'Editing a Cupón' do
    before do
      @cupon = create(:cupon, tienda: @tienda, tipo_descuento: 'importe', importe: 300)
    end

    it 'updates a cupon' do
      login_as_admin
      visit '/cupones'

      within('tr', text: @cupon.codigo) do
        find('i.ti-marker-alt').click
      end

      within('.modal', wait: 10) do
        fill_in 'cupon_importe', with: '750'
        click_button 'Guardar'
      end

      expect(page).not_to have_css('.modal', visible: true, wait: 5)

      @cupon.reload
      expect(@cupon.importe.to_f).to eq(750.0)
    end
  end

  context 'Deleting a Cupón' do
    before do
      @cupon = create(:cupon, tienda: @tienda)
    end

    it 'deletes a cupon' do
      login_as_admin
      visit '/cupones'

      expect(page).to have_content(@cupon.codigo)

      within('tr', text: @cupon.codigo) do
        accept_confirm do
          find('i.ti-trash').click
        end
      end

      # Wait for deletion to complete - flash message may contain the code,
      # so check that the table row is gone instead
      expect(page).to have_content('eliminado correctamente', wait: 5)
      expect(Cupones::Cupon.find_by(id: @cupon.id)).to be_nil
    end
  end

  context 'Navigation' do
    it 'shows Cupones in Contactos menu' do
      login_as_admin
      visit '/inicio'

      # Sidebar starts collapsed (mini-sidebar), expand it first
      find('.sidebartoggler', match: :first).click

      expect(page).to have_link('Cupones', href: '/cupones')
    end
  end
end
