# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Opciones Checkout Page', :js, type: :system do
  # --- Horario de entrega on comprar page (cuenta corriente flow) ---
  describe 'Horario de entrega on comprar page' do
    # Conditions for Horario select on comprar (_pedido.html.erb):
    #   can?(:aceptar, @pedido)  => cuenta_corriente_habilitada? + estado 1 + productos_solicitados.present?
    #   @pedido.pendiente?
    #   @pedido.cuenta
    #   @pedido.cuenta.cliente.horarios_de_entrega?
    #   tienda_activa.horarios_de_entrega?

    let!(:tienda) do
      create(:tienda,
             nombre: 'Horario Test Store',
             dominio: 'localhost',
             carrito_de_compras: true,
             horarios_de_entrega: true,
             maneja_stock: false)
    end
    let!(:pedido) do
      p = build(:pedido, tienda: tienda, cuenta: cuenta, estado_id: 1,
                         fecha: cuenta.proximo_dia_pedido, autor: usuario, usuario: usuario)
      p.asignar_cuenta_manual
      p.cuenta = cuenta
      p.save!
      create(:producto_solicitado, pedido: p, producto: producto, cantidad: 2, precio_unitario: 100.0)
      p
    end
    let!(:local) { create(:local, tienda: tienda, nombre: 'Local H', domicilio: 'Calle H 123', telefono: '111') }
    let!(:cliente) do
      create(:cliente,
             tienda: tienda,
             nombre: 'CC Horario Cliente',
             cuenta_corriente: true,
             horarios_de_entrega: true,
             usuario_puede_elegir_cuenta: false,
             permitir_envios_a_domicilio: false)
    end
    let!(:cuenta) { create(:cuenta, nombre: 'Cuenta Horario', cliente: cliente) }
    let!(:usuario) do
      create(:usuario, :cliente,
             login: 'clientehorario',
             password: 'password123',
             password_confirmation: 'password123',
             nombre: 'Horario User',
             email: 'horario@test.com',
             cuenta: cuenta,
             tienda_cliente: tienda,
             visualizando_tienda: tienda)
    end
    let!(:categoria) { create(:categoria, nombre: 'Snacks', tienda: tienda, stock_activo: false) }
    let!(:producto) { create(:producto, nombre: 'Galletas', tienda: tienda, categoria: categoria) }
    let!(:horario_manana) { Pedidos::Horario.create!(nombre: '9:00 - 12:00', horario: '9:00 - 12:00', tienda: tienda) }
    let!(:horario_tarde) { Pedidos::Horario.create!(nombre: '14:00 - 17:00', horario: '14:00 - 17:00', tienda: tienda) }

    before do
      create(:precio, :for_cliente, producto: producto, cliente: cliente, importe: 100, fecha_desde: Time.zone.today)
      driven_by :selenium_remote
      visit root_path
      fill_in 'username', with: 'clientehorario'
      fill_in 'password', with: 'password123'
      click_button 'Iniciar sesión'
    end

    it 'shows Horario select on comprar page when conditions are met' do
      visit pedido_comprar_path(pedido)

      expect(page).to have_css('#confirmed-status', wait: 5)
      expect(page).to have_select('pedido_horario_id')
      expect(page).to have_content('Horario')
    end

    it 'lists all active horarios in the dropdown' do
      visit pedido_comprar_path(pedido)

      expect(page).to have_select('pedido_horario_id', with_options: ['9:00 - 12:00', '14:00 - 17:00'])
    end

    it 'does not show discontinued horarios' do
      horario_tarde.discontinue!
      visit pedido_comprar_path(pedido)

      options = page.all('#pedido_horario_id option').map(&:text)
      expect(options).to include('9:00 - 12:00')
      expect(options).not_to include('14:00 - 17:00')
    end

    it 'pre-selects the assigned horario' do
      pedido.update_column(:horario_id, horario_manana.id)
      visit pedido_comprar_path(pedido)

      expect(page).to have_select('pedido_horario_id', selected: '9:00 - 12:00')
    end

    context 'when tienda has horarios_de_entrega disabled' do
      before { tienda.update_column(:horarios_de_entrega, false) }

      it 'does not show the Horario select' do
        visit pedido_comprar_path(pedido)

        expect(page).to have_css('#confirmed-status', wait: 5)
        expect(page).not_to have_select('pedido_horario_id')
      end
    end

    context 'when cliente has horarios_de_entrega disabled' do
      before { cliente.update_column(:horarios_de_entrega, false) }

      it 'does not show the Horario select' do
        visit pedido_comprar_path(pedido)

        expect(page).to have_css('#confirmed-status', wait: 5)
        expect(page).not_to have_select('pedido_horario_id')
      end
    end
  end

  # --- Opciones page: enviar_a, horario (legacy), turno validations ---
  describe 'Opciones page validations' do
    # Conditions for the opciones page (non-CC flow):
    #   can?(:pagar_mercadopago) => !cuenta_corriente_habilitada? + estado 1 + productos present
    #   enviar_a: cliente.permitir_envios_a_domicilio? || cliente.usuario_puede_elegir_cuenta?
    #   horario (legacy): !carrito_de_compras + cliente.horarios_de_entrega? + tienda.horarios_de_entrega?
    #   turno: carrito_de_compras + cliente.turnos_activos.any?

    context 'Enviar A validation' do
      let!(:tienda) do
        create(:tienda,
               nombre: 'EnviarA Test Store',
               dominio: 'localhost',
               carrito_de_compras: true,
               horarios_de_entrega: false,
               maneja_stock: false)
      end
      let!(:pedido) do
        # Use next weekday to avoid "Sábados y Domingos no se cocina" validation
        fecha = Date.current + 1.day
        fecha += 1.day while fecha.saturday? || fecha.sunday?
        p = build(:pedido, tienda: tienda, cuenta: cuenta, estado_id: 1,
                           fecha: fecha, autor: usuario, usuario: usuario)
        p.asignar_cuenta_manual
        p.cuenta = cuenta
        p.save!
        create(:producto_solicitado, pedido: p, producto: producto, cantidad: 1, precio_unitario: 80.0)
        p
      end
      let!(:local) { create(:local, tienda: tienda, nombre: 'Local E', domicilio: 'Calle E 123', telefono: '222') }
      let!(:cliente) do
        create(:cliente,
               tienda: tienda,
               nombre: 'EnviarA Cliente',
               cuenta_corriente: false,
               horarios_de_entrega: false,
               usuario_puede_elegir_cuenta: true,
               permitir_envios_a_domicilio: false)
      end
      let!(:cuenta) { create(:cuenta, nombre: 'Cuenta Main', cliente: cliente, cuenta_corriente_parcial: nil) }
      let!(:cuenta2) { create(:cuenta, nombre: 'Cuenta Branch', cliente: cliente, cuenta_corriente_parcial: nil) }
      let!(:usuario) do
        create(:usuario, :cliente,
               login: 'clienteenviar',
               password: 'password123',
               password_confirmation: 'password123',
               nombre: 'EnviarA User',
               email: 'enviara@test.com',
               cuenta: cuenta,
               tienda_cliente: tienda,
               visualizando_tienda: tienda)
      end
      let!(:categoria) { create(:categoria, nombre: 'Food', tienda: tienda, stock_activo: false) }
      let!(:producto) { create(:producto, nombre: 'Sandwich', tienda: tienda, categoria: categoria) }

      before do
        create(:precio, :for_cliente, producto: producto, cliente: cliente, importe: 80, fecha_desde: Time.zone.today)
        driven_by :selenium_remote
        visit root_path
        fill_in 'username', with: 'clienteenviar'
        fill_in 'password', with: 'password123'
        click_button 'Iniciar sesión'
      end

      it 'shows Enviar A dropdown on comprar page when usuario_puede_elegir_cuenta' do
        visit pedido_comprar_path(pedido)

        expect(page).to have_css('#confirmed-status', wait: 5)
        expect(page).to have_select('pedido_enviar_a_id')
        expect(page).to have_content('Enviar a')
      end

      it 'lists all cuentas in the Enviar A dropdown' do
        visit pedido_comprar_path(pedido)

        options = page.all('#pedido_enviar_a_id option').map(&:text).compact_blank
        expect(options.any? { |o| o.include?('Cuenta Main') || o.include?(cuenta.cliente_y_nombre) }).to be true
      end

      it 'shows MP preference container without validation hint when cuenta is selected' do
        # In the new flow `enviar_a_id` is derived from `cuenta`. Once a cuenta
        # is assigned (which always happens at pedido save time), the field is
        # never blank, so the Enviar A validation never triggers from the UI.
        # The dropdown is always populated with at least the current cuenta.
        visit pedido_comprar_path(pedido)

        expect(page).to have_css('#preference-container', wait: 5)
        expect(page).not_to have_css('#mp-payment-validation-hint', visible: :visible, wait: 5)
      end

      context 'with permitir_envios_a_domicilio enabled' do
        before { cliente.update_column(:permitir_envios_a_domicilio, true) }

        it 'shows Domicilio Particular option in Enviar A dropdown' do
          visit pedido_comprar_path(pedido)

          options = page.all('#pedido_enviar_a_id option').map(&:text)
          expect(options).to include('Domicilio Particular')
        end

        it 'shows direccion input when Domicilio Particular is selected' do
          visit pedido_comprar_path(pedido)

          select 'Domicilio Particular', from: 'pedido_enviar_a_id'
          expect(page).to have_css('#wraper-direccion:not(.hide)', wait: 5)
        end
      end

      context 'when usuario_puede_elegir_cuenta is disabled' do
        before do
          cliente.update_column(:usuario_puede_elegir_cuenta, false)
          cliente.update_column(:permitir_envios_a_domicilio, false)
        end

        it 'does not show the Enviar A select on comprar page' do
          visit pedido_comprar_path(pedido)

          expect(page).to have_css('#confirmed-status', wait: 5)
          expect(page).not_to have_select('pedido_enviar_a_id')
        end
      end
    end
  end
end
