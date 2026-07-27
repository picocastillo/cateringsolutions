# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Descuentos Venta Mostrador ABM', :js, type: :system do
  before do
    @tienda = create(:tienda,
                     nombre: 'Tienda Descuentos ABM',
                     dominio: 'localhost',
                     telefono: '123456789',
                     email: 'test@descuentosabm.com',
                     venta_mostrador: true,
                     carrito_de_compras: true)

    @admin = create(:usuario, :admin,
                    login: 'admindescabm',
                    password: 'password123',
                    password_confirmation: 'password123',
                    nombre: 'Admin Descuentos ABM',
                    email: 'admindescabm@example.com',
                    visualizando_tienda: @tienda)
    @admin.tiendas << @tienda unless @admin.tiendas.include?(@tienda)
  end

  def login_and_visit_descuentos
    visit root_path
    fill_in 'username', with: 'admindescabm'
    fill_in 'password', with: 'password123'
    click_button 'Iniciar sesión'
    expect(page).to have_current_path('/inicio', wait: 10, ignore_query: true)
    visit ventas_mostrador_descuentos_path
    expect(page).to have_content('Descuentos Venta Mostrador', wait: 10)
  end

  context 'Index' do
    it 'displays existing descuentos with their attributes' do
      create(:descuento_venta_mostrador, tienda: @tienda, nombre: 'Efectivo $500',
                                         tipo_descuento: 'importe', importe: 500,
                                         medio_pago_tipo: 'efectivo', importe_minimo: 10_000)
      create(:descuento_venta_mostrador, :porcentaje_con_limite, tienda: @tienda,
                                                                 nombre: 'QR 15%', medio_pago_tipo: 'qr',
                                                                 importe_minimo: 5000)

      login_and_visit_descuentos

      expect(page).to have_content('Efectivo $500')
      expect(page).to have_content('QR 15%')
      expect(page).to have_content('Efectivo')
      expect(page).to have_content('QR')
      expect(page).to have_css('.label-success', text: 'Activo', count: 2)
    end

    it 'shows inactive badge for inactive descuentos' do
      create(:descuento_venta_mostrador, :inactivo, tienda: @tienda, nombre: 'Inactivo Test')

      login_and_visit_descuentos

      expect(page).to have_content('Inactivo Test')
      expect(page).to have_css('.label-default', text: 'Inactivo')
    end
  end

  context 'Creating a descuento' do
    it 'creates a descuento with importe fijo' do
      login_and_visit_descuentos

      click_link 'Nuevo'

      within('.modal', wait: 10) do
        expect(page).to have_content('Nuevo Descuento Venta Mostrador')

        fill_in 'descuento_venta_mostrador_nombre', with: 'Desc Efectivo $1000'
        select 'Efectivo', from: 'descuento_venta_mostrador_medio_pago_tipo'
        select 'Importe Fijo', from: 'descuento_vm_tipo_descuento'
        fill_in 'descuento_venta_mostrador_importe', with: '1000'
        fill_in 'descuento_venta_mostrador_importe_minimo', with: '5000'

        click_button 'Crear'
      end

      expect(page).not_to have_css('.modal', visible: true, wait: 5)

      descuento = VentasMostrador::DescuentoVentaMostrador.last
      expect(descuento).to be_present
      expect(descuento.nombre).to eq('Desc Efectivo $1000')
      expect(descuento.tipo_descuento).to eq('importe')
      expect(descuento.importe.to_f).to eq(1000.0)
      expect(descuento.medio_pago_tipo).to eq('efectivo')
      expect(descuento.importe_minimo.to_f).to eq(5000.0)
      expect(descuento.activo).to be true
    end

    it 'creates a descuento with porcentaje y limite' do
      login_and_visit_descuentos

      click_link 'Nuevo'

      within('.modal', wait: 10) do
        fill_in 'descuento_venta_mostrador_nombre', with: 'QR 10% max 2000'
        select 'QR', from: 'descuento_venta_mostrador_medio_pago_tipo'
        select 'Porcentaje con Límite', from: 'descuento_vm_tipo_descuento'
        fill_in 'descuento_venta_mostrador_porcentaje', with: '10'
        fill_in 'descuento_venta_mostrador_limite_bonificacion', with: '2000'
        fill_in 'descuento_venta_mostrador_importe_minimo', with: '0'

        click_button 'Crear'
      end

      expect(page).not_to have_css('.modal', visible: true, wait: 5)

      descuento = VentasMostrador::DescuentoVentaMostrador.last
      expect(descuento).to be_present
      expect(descuento.tipo_descuento).to eq('porcentaje')
      expect(descuento.porcentaje.to_f).to eq(10.0)
      expect(descuento.limite_bonificacion.to_f).to eq(2000.0)
      expect(descuento.medio_pago_tipo).to eq('qr')
    end

    it 'shows validation errors for invalid data' do
      login_and_visit_descuentos

      click_link 'Nuevo'

      within('.modal', wait: 10) do
        fill_in 'descuento_venta_mostrador_nombre', with: ''
        click_button 'Crear'

        expect(page).to have_css('.is-invalid, .form-group-invalid, .alert-danger', wait: 5)
      end

      expect(VentasMostrador::DescuentoVentaMostrador.count).to eq(0)
    end
  end

  context 'Editing a descuento' do
    before do
      @descuento = create(:descuento_venta_mostrador, tienda: @tienda,
                                                      nombre: 'Editable', importe: 300)
    end

    it 'updates a descuento' do
      login_and_visit_descuentos

      within('tr', text: 'Editable') do
        find('i.ti-marker-alt').click
      end

      within('.modal', wait: 10) do
        fill_in 'descuento_venta_mostrador_nombre', with: 'Actualizado'
        fill_in 'descuento_venta_mostrador_importe', with: '750'
        click_button 'Guardar'
      end

      expect(page).not_to have_css('.modal', visible: true, wait: 5)

      @descuento.reload
      expect(@descuento.nombre).to eq('Actualizado')
      expect(@descuento.importe.to_f).to eq(750.0)
    end
  end

  context 'Toggle activo' do
    before do
      @descuento = create(:descuento_venta_mostrador, tienda: @tienda,
                                                      nombre: 'Toggleable', activo: true)
    end

    it 'deactivates an active descuento' do
      login_and_visit_descuentos

      within('tr', text: 'Toggleable') do
        accept_confirm do
          find('i.ti-na').click
        end
      end

      expect(page).to have_content('desactivado correctamente', wait: 5)
      expect(@descuento.reload.activo).to be false
    end
  end

  context 'Deleting a descuento' do
    before do
      @descuento = create(:descuento_venta_mostrador, tienda: @tienda, nombre: 'Borrable')
    end

    it 'deletes a descuento' do
      login_and_visit_descuentos

      expect(page).to have_content('Borrable')

      within('tr', text: 'Borrable') do
        accept_confirm do
          find('i.ti-trash').click
        end
      end

      expect(page).to have_content('eliminado correctamente', wait: 5)
      expect(VentasMostrador::DescuentoVentaMostrador.find_by(id: @descuento.id)).to be_nil
    end
  end

  context 'Navigation' do
    it 'shows Descuentos VM link is accessible when venta_mostrador is enabled' do
      login_and_visit_descuentos

      # Verify the page is accessible and shows the right content
      expect(page).to have_content('Descuentos Venta Mostrador')
      expect(page).to have_current_path(ventas_mostrador_descuentos_path)
    end
  end
end
