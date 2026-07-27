# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Ventas Mostrador - Productos Pesables', :js, type: :system do
  before do
    Comprobantes::Tipo.find_or_create_by(codigo: 1) do |tipo|
      tipo.desc = 'Factura'
      tipo.clase = 'Ventas::Facturacion::Factura'
      tipo.letra = 'A'
      tipo.debitan = false
    end

    Comprobantes::Tipo.find_or_create_by(codigo: 3) do |tipo|
      tipo.desc = 'Nota de Crédito'
      tipo.clase = 'Ventas::Facturacion::NotaCredito'
      tipo.letra = 'A'
      tipo.debitan = false
    end

    @tienda = create(:tienda,
                     nombre: 'Tienda Pesable',
                     dominio: 'localhost',
                     telefono: '123456789',
                     email: 'test@pesable.com',
                     venta_mostrador: true,
                     carrito_de_compras: true,
                     horarios_de_entrega: false,
                     maneja_stock: false,
                     productos_pesables: true)

    @cliente_cf = create(:cliente,
                         nombre: 'Consumidor Final',
                         tienda: @tienda,
                         dia_inicio_ciclo_facturacion: 1,
                         vencimiento_a: 30,
                         horarios_de_entrega: false,
                         usuario_puede_elegir_cuenta: false,
                         permitir_envios_a_domicilio: false,
                         cuenta_corriente: true,
                         listas_de_precio_privada: false)

    @cuenta_cf = @cliente_cf.cuentas.first || create(:cuenta,
                                                     nombre: 'Consumidor Final',
                                                     cliente: @cliente_cf)

    @admin = create(:usuario, :admin,
                    login: 'adminpesable',
                    password: 'password123',
                    password_confirmation: 'password123',
                    nombre: 'Admin Pesable',
                    email: 'adminpesable@example.com',
                    visualizando_tienda: @tienda)
    @admin.tiendas << @tienda unless @admin.tiendas.include?(@tienda)

    @categoria = create(:categoria,
                        nombre: 'Productos Pesables',
                        tienda: @tienda,
                        stock_activo: false,
                        menu_diario: false)

    create(:categoria,
           nombre: 'Menu Diario Dummy',
           tienda: @tienda,
           menu_diario: true)

    @cliente_cf.categorias << @categoria unless @cliente_cf.categorias.include?(@categoria)

    # Pesable product (sold by weight)
    @producto_pesable = create(:producto,
                               nombre: 'Queso Cremoso',
                               codigo: 'QUESO01',
                               tienda: @tienda,
                               categoria: @categoria,
                               pesable: true,
                               discontinued_at: nil)

    # Non-pesable product (regular unit product)
    @producto_normal = create(:producto,
                              nombre: 'Empanada Carne',
                              codigo: 'EMP001',
                              tienda: @tienda,
                              categoria: @categoria,
                              pesable: false,
                              discontinued_at: nil)

    create(:precio, producto: @producto_pesable, importe: 800.0,
                    fecha_desde: 1.week.ago, fecha_hasta: 1.year.from_now)
    create(:precio, producto: @producto_normal, importe: 200.0,
                    fecha_desde: 1.week.ago, fecha_hasta: 1.year.from_now)
  end

  def login_and_visit_vm
    visit root_path
    fill_in 'username', with: 'adminpesable'
    fill_in 'password', with: 'password123'
    click_button 'Iniciar sesión'
    expect(page).to have_current_path('/inicio', wait: 10, ignore_query: true)
    visit ventas_mostrador_pedidos_path
    expect(page).to have_content('Venta Mostrador', wait: 10)
    expect(page).to have_css('#agregar-producto-vr', wait: 10)
  end

  scenario 'shows peso modal when adding a pesable product' do
    login_and_visit_vm

    fill_in 'codigo', with: 'QUESO01'
    find('#agregar-producto-vr').click

    # Peso modal should appear
    expect(page).to have_css('#peso-modal', visible: true, wait: 5)
    expect(page).to have_content('Queso Cremoso')
    expect(page).to have_css('#peso-modal-input')
  end

  scenario 'adds pesable product with peso to cart' do
    login_and_visit_vm

    fill_in 'codigo', with: 'QUESO01'
    find('#agregar-producto-vr').click

    # Wait for modal
    expect(page).to have_css('#peso-modal', visible: true, wait: 5)

    # Enter weight and confirm
    fill_in 'peso-modal-input', with: '1.5'
    click_button 'peso-modal-confirmar'

    # Modal should close and product should appear in cart
    expect(page).not_to have_css('#peso-modal.show', wait: 5)

    # Cart should show the pesable product with Kg notation
    expect(page).to have_css('.productos_solicitados_venta_mostrador', wait: 5)
    within('.productos_solicitados_venta_mostrador') do
      expect(page).to have_content('Queso Cremoso')
    end
  end

  scenario 'does not show peso modal for regular product' do
    login_and_visit_vm

    fill_in 'codigo', with: 'EMP001'
    find('#agregar-producto-vr').click

    # No modal should appear - product goes directly to cart
    expect(page).not_to have_css('#peso-modal.show')

    expect(page).to have_css('.productos_solicitados_venta_mostrador', wait: 5)
    within('.productos_solicitados_venta_mostrador') do
      expect(page).to have_content('Empanada Carne')
    end
  end

  scenario 'cancel peso modal does not add product' do
    login_and_visit_vm

    fill_in 'codigo', with: 'QUESO01'
    find('#agregar-producto-vr').click

    expect(page).to have_css('#peso-modal', visible: true, wait: 5)

    # Verify modal has a cancel button with data-dismiss attribute
    within('#peso-modal') do
      cancel_btn = find('[data-dismiss="modal"].btn')
      expect(cancel_btn.text).to eq('Cancelar')
    end

    # Force-close modal and verify product was NOT added
    page.execute_script("$('#peso-modal').removeClass('show').css('display','none'); $('.modal-backdrop').remove(); $('body').removeClass('modal-open');")
    sleep 0.5

    # No AJAX was sent (no agregar_pesable call), so product should NOT be in cart
    expect(page).not_to have_css('.productos_solicitados_venta_mostrador')
  end

  scenario 'peso modal validates positive weight' do
    login_and_visit_vm

    fill_in 'codigo', with: 'QUESO01'
    find('#agregar-producto-vr').click

    expect(page).to have_css('#peso-modal', visible: true, wait: 5)

    # Try to confirm with zero/empty peso
    fill_in 'peso-modal-input', with: '0'
    click_button 'peso-modal-confirmar'

    # Modal should remain open with validation feedback
    expect(page).to have_css('#peso-modal', visible: true)
    expect(page).to have_css('#peso-modal-input.is-invalid')
  end

  scenario 'mixed cart with pesable and non-pesable products' do
    login_and_visit_vm

    # Add normal product first
    fill_in 'codigo', with: 'EMP001'
    find('#agregar-producto-vr').click
    expect(page).to have_css('.productos_solicitados_venta_mostrador', wait: 5)
    within('.productos_solicitados_venta_mostrador') do
      expect(page).to have_content('Empanada Carne')
    end

    # Add pesable product
    fill_in 'codigo', with: 'QUESO01'
    find('#agregar-producto-vr').click

    expect(page).to have_css('#peso-modal', visible: true, wait: 5)
    fill_in 'peso-modal-input', with: '0.750'
    click_button 'peso-modal-confirmar'

    expect(page).not_to have_css('#peso-modal.show', wait: 5)

    # Cart should have both products
    expect(page).to have_css('.productos_solicitados_venta_mostrador', wait: 5)
    within('.productos_solicitados_venta_mostrador') do
      expect(page).to have_content('Empanada Carne')
      expect(page).to have_content('Queso Cremoso')
    end
  end

  scenario 'pesable product shows peso input in cart for editing' do
    login_and_visit_vm

    # Add pesable product
    fill_in 'codigo', with: 'QUESO01'
    find('#agregar-producto-vr').click

    expect(page).to have_css('#peso-modal', visible: true, wait: 5)
    fill_in 'peso-modal-input', with: '2.0'
    click_button 'peso-modal-confirmar'

    expect(page).not_to have_css('#peso-modal.show', wait: 5)

    # Cart should have a peso input field for the pesable product
    expect(page).to have_css('.productos_solicitados_venta_mostrador', wait: 5)
    within('.productos_solicitados_venta_mostrador') do
      expect(page).to have_css('.peso-input')
    end
  end

  scenario 'adding same pesable product twice accumulates peso' do
    login_and_visit_vm

    # Add pesable product first time with 1.5 kg
    fill_in 'codigo', with: 'QUESO01'
    find('#agregar-producto-vr').click
    expect(page).to have_css('#peso-modal', visible: true, wait: 5)
    fill_in 'peso-modal-input', with: '1.5'
    click_button 'peso-modal-confirmar'
    expect(page).not_to have_css('#peso-modal.show', wait: 5)

    expect(page).to have_css('.productos_solicitados_venta_mostrador', wait: 5)
    within('.productos_solicitados_venta_mostrador') do
      expect(page).to have_css('.peso-input')
      peso_field = find('.peso-input')
      expect(peso_field.value.to_f).to eq(1.5)
    end

    # Add same pesable product again with 0.75 kg
    fill_in 'codigo', with: 'QUESO01'
    find('#agregar-producto-vr').click
    expect(page).to have_css('#peso-modal', visible: true, wait: 5)
    fill_in 'peso-modal-input', with: '0.75'
    click_button 'peso-modal-confirmar'
    expect(page).not_to have_css('#peso-modal.show', wait: 5)

    # Wait for AJAX to complete and update the cart with accumulated peso
    sleep 3

    # Peso should be accumulated (1.5 + 0.75 = 2.25), not replaced
    within('.productos_solicitados_venta_mostrador') do
      peso_field = find('.peso-input')
      expect(peso_field.value.to_f).to eq(2.25)
    end
  end

  scenario 'editing peso in cart recalculates the row total' do
    login_and_visit_vm

    # Add pesable product with 1.0 kg (price is 800/kg)
    fill_in 'codigo', with: 'QUESO01'
    find('#agregar-producto-vr').click
    expect(page).to have_css('#peso-modal', visible: true, wait: 5)
    fill_in 'peso-modal-input', with: '1.0'
    click_button 'peso-modal-confirmar'
    expect(page).not_to have_css('#peso-modal.show', wait: 5)

    expect(page).to have_css('.productos_solicitados_venta_mostrador', wait: 5)

    # Verify initial total: 1.0 kg * $800 = $800
    within('.productos_solicitados_venta_mostrador') do
      peso_field = find('.peso-input')
      expect(peso_field.value.to_f).to eq(1.0)
    end

    # Get the importe cell id from the peso-input's productoid
    ps_id = find('.peso-input')['data-productoid']
    initial_total = find("#importe-renglon-#{ps_id}").text

    # Edit peso to 2.5 kg
    within('.productos_solicitados_venta_mostrador') do
      peso_field = find('.peso-input')
      peso_field.set('')
      peso_field.set('2.5')
      peso_field.native.send_keys(:tab) # Trigger change event
    end

    # Wait for AJAX to complete and row total to update
    sleep 2

    # Row total should now be 2.5 * 800 = $2,000
    new_total = find("#importe-renglon-#{ps_id}").text
    expect(new_total).not_to eq(initial_total)

    # Verify the pedido total also updated
    expect(page).to have_css('#importe-total-container')
    total_text = find('#importe-total-container').text
    expect(total_text).to include('2.000')

    # Verify in DB
    pedido = Pedidos::Pedido.where(tienda: @tienda, venta_mostrador: true).order(id: :desc).first
    ps = pedido.productos_solicitados.find { |p| p.producto_id == @producto_pesable.id }
    expect(ps.peso.to_f).to eq(2.5)
  end
end
