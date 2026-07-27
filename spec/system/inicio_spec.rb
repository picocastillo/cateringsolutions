require 'rails_helper'

RSpec.describe 'Inicio page', :js, type: :system do
  let(:tienda) { create(:tienda, nombre: 'Test Store', carrito_de_compras: true) }
  let(:admin) { create(:usuario, :admin, :with_password, visualizando_tienda: tienda) }

  before do
    admin.tiendas << tienda unless admin.tiendas.include?(tienda)
  end

  describe 'horarios_de_corte_ids filter' do
    let(:cliente_07) { create(:cliente, tienda: tienda, nombre: 'Cliente 7am', horario_corte_pedidos: '07:00') }
    let(:cuenta_07) { create(:cuenta, cliente: cliente_07) }
    let(:cliente_12) { create(:cliente, tienda: tienda, nombre: 'Cliente 12pm', horario_corte_pedidos: '12:00') }
    let(:cuenta_12) { create(:cuenta, cliente: cliente_12) }

    let(:categoria) { create(:categoria, tienda: tienda, nombre: 'Comidas') }
    let(:producto) { create(:producto, tienda: tienda, categoria: categoria, nombre: 'Empanada') }

    before do
      create(:precio, producto: producto, importe: 150)

      # Create confirmed pedidos for each cuenta
      [cuenta_07, cuenta_12].each do |cta|
        pedido = Pedidos::Pedido.new(
          tienda: tienda, cuenta: cta, fecha: Date.current,
          estado_id: 1, autor: admin, usuario: admin
        )
        pedido.save(validate: false)
        ps = Productos::ProductoSolicitado.new(
          pedido: pedido, producto: producto, cantidad: 2, precio_unitario: 150
        )
        ps.save(validate: false)
        pedido.update_column(:estado_id, 3)
      end
    end

    it 'filters by horario de corte without error when passed as array' do
      admin_login(admin, 'password123')

      # Visit inicio with horarios_de_corte_ids as array params (reproduces production bug)
      visit "/inicio?q%5Bhorarios_de_corte_ids%5D%5B%5D=07%3A00&q%5Bfecha_desde%5D=#{Date.current.strftime('%d/%m/%Y')}&q%5Bfecha_hasta%5D=#{Date.current.strftime('%d/%m/%Y')}&commit=Buscar"

      expect(page).to have_content('Productos a cocinar')
      expect(page).not_to have_content("can't quote Array")
      expect(page).not_to have_content('TypeError')
    end

    it 'filters by multiple horarios de corte without error' do
      admin_login(admin, 'password123')

      visit "/inicio?q%5Bhorarios_de_corte_ids%5D%5B%5D=07%3A00&q%5Bhorarios_de_corte_ids%5D%5B%5D=12%3A00&q%5Bfecha_desde%5D=#{Date.current.strftime('%d/%m/%Y')}&q%5Bfecha_hasta%5D=#{Date.current.strftime('%d/%m/%Y')}&commit=Buscar"

      expect(page).to have_content('Productos a cocinar')
      expect(page).not_to have_content("can't quote Array")
    end
  end

  describe 'pedido cocina new and create from inicio' do
    let(:cliente) { create(:cliente, tienda: tienda, nombre: 'Restaurante Test', horario_corte_pedidos: '08:00') }
    let(:cuenta) { create(:cuenta, cliente: cliente, nombre: 'Cuenta Principal') }
    let(:categoria) { create(:categoria, tienda: tienda, nombre: 'Comidas') }
    let(:producto1) { create(:producto, tienda: tienda, categoria: categoria, nombre: 'Empanada de Carne') }
    let(:producto2) { create(:producto, tienda: tienda, categoria: categoria, nombre: 'Pizza Muzzarella') }

    before do
      create(:precio, producto: producto1, importe: 150)
      create(:precio, producto: producto2, importe: 800)

      # Create confirmed pedidos using the proper asignar_cuenta_manual pattern
      [producto1, producto2].each_with_index do |prod, i|
        pedido = create(:pedido,
                        tienda: tienda,
                        cuenta: cuenta,
                        autor: admin,
                        usuario: admin,
                        fecha: Date.current,
                        estado_id: 1)
        pedido.asignar_cuenta_manual
        pedido.cuenta = cuenta
        pedido.save!
        create(:producto_solicitado,
               pedido: pedido,
               producto: prod,
               cantidad: i + 1,
               precio_unitario: prod == producto1 ? 150 : 800)
        pedido.update!(estado_id: 3)
      end
    end

    it 'shows pedidos on the new form and creates a pedido cocina' do
      admin_login(admin, 'password123')

      visit new_pedido_cocina_path

      expect(page).to have_content('Pedidos listos para Cocinar')
      expect(page).to have_content('Restaurante Test')

      click_button 'Crear'

      expect(page).to have_content('Pedido de cocina creado exitosamente', wait: 10)
      expect(Pedidos::PedidoCocina.count).to eq(1)
      expect(Pedidos::PedidoCocina.last.pedidos.count).to eq(2)
    end

    it 'redirects when no pedidos are available' do
      # Remove all confirmado pedidos
      Pedidos::Pedido.update_all(estado_id: 1)

      admin_login(admin, 'password123')

      visit "#{find_pedidos_pedidos_cocina_path}?commit=Crear&q%5Bfecha_desde%5D=#{Date.current.strftime('%d/%m/%Y')}&q%5Bfecha_hasta%5D=#{Date.current.strftime('%d/%m/%Y')}"

      expect(page).to have_content('No hay pedidos listos para cocinar en la fecha seleccionada', wait: 10)
    end
  end

  describe 'two-panel split: cocina vs venta mostrador' do
    let(:tienda_vm) { create(:tienda, nombre: 'Tienda VM', carrito_de_compras: true, venta_mostrador: true) }
    let(:admin_vm) do
      u = create(:usuario, :admin, :with_password, visualizando_tienda: tienda_vm)
      # Add all tiendas so login succeeds regardless of which tienda resolves from
      # the domain on the login page (Tiendas::Tienda.first in test env).
      Tiendas::Tienda.find_each do |t|
        u.tiendas << t unless u.tiendas.include?(t)
      end
      u
    end
    let(:cliente_vm) { create(:cliente, tienda: tienda_vm, nombre: 'Cliente VM') }
    let(:cuenta_vm) { create(:cuenta, cliente: cliente_vm) }
    let(:categoria_vm) { create(:categoria, tienda: tienda_vm, nombre: 'Comidas') }
    let(:producto_cocina) { create(:producto, tienda: tienda_vm, categoria: categoria_vm, nombre: 'Milanesa') }
    let(:producto_vm) { create(:producto, tienda: tienda_vm, categoria: categoria_vm, nombre: 'Empanada VM') }

    before do
      admin_vm.tiendas << tienda_vm unless admin_vm.tiendas.include?(tienda_vm)

      # Pedido normal (non-VM)
      pedido_normal = Pedidos::Pedido.new(tienda: tienda_vm, cuenta: cuenta_vm, fecha: Date.current,
                                          estado_id: 1, autor: admin_vm, usuario: admin_vm)
      pedido_normal.save(validate: false)
      Productos::ProductoSolicitado.new(pedido: pedido_normal, producto: producto_cocina, cantidad: 3,
                                        precio_unitario: 200, precio_con_descuento: 200).save(validate: false)
      pedido_normal.update_columns(estado_id: 3, venta_mostrador: false)

      # Pedido VM
      pedido_vm = Pedidos::Pedido.new(tienda: tienda_vm, cuenta: cuenta_vm, fecha: Date.current,
                                      estado_id: 1, autor: admin_vm, usuario: admin_vm)
      pedido_vm.save(validate: false)
      Productos::ProductoSolicitado.new(pedido: pedido_vm, producto: producto_vm, cantidad: 5,
                                        precio_unitario: 100, precio_con_descuento: 100).save(validate: false)
      pedido_vm.update_columns(estado_id: 3, venta_mostrador: true)
    end

    it 'shows both panels with correct products' do
      admin_login(admin_vm, 'password123')
      visit '/inicio'

      # Cocina panel
      expect(page).to have_content('Productos a cocinar')
      within('#reporte-cocina') do
        expect(page).to have_content('Milanesa')
        expect(page).not_to have_content('Empanada VM')
      end

      # VM panel
      expect(page).to have_content('Productos Venta Mostrador')
      within('#reporte-vm') do
        expect(page).to have_content('Empanada VM')
        expect(page).not_to have_content('Milanesa')
      end
    end
  end
end
