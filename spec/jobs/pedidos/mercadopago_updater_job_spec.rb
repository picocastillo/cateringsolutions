require 'rails_helper'

RSpec.describe Pedidos::MercadopagoUpdaterJob, type: :job do
  let(:tienda) { Tiendas::Tienda.create!(nombre: 'Tienda Job', maneja_stock: false) }
  let(:cliente) do
    Clientes::Cliente.create!(
      nombre: 'Cliente Job', cuit: '20294834487',
      dia_inicio_ciclo_facturacion: 1, vencimiento_a: 1,
      horario_corte_pedidos: '23:00', tienda: tienda
    )
  end
  let(:cuenta) { Clientes::Cuenta.create!(cliente: cliente, nombre: 'Cuenta Job') }
  let(:usuario) do
    Usuarios::Usuario.create!(
      nombre: 'Usuario Job', login: 'usuariojob',
      password: 'password123', password_confirmation: 'password123',
      email: 'job@example.com', tipo_usuario_id: 1, dni: 77_000_001,
      cuenta: cuenta, tienda_cliente: tienda
    )
  end
  let(:grupo) { Pedidos::PedidoMultiple.create!(usuario: usuario) }

  describe '#perform — multi-pedido path' do
    let(:approved_response) do
      {
        'external_reference' => "multiple-#{grupo.id}-#{usuario.id}",
        'status' => 'approved',
        'id' => 99_999,
        'status_detail' => 'accredited',
        'currency_id' => 'ARS',
        'transaction_amount' => '100.0',
        'installments' => 1,
        'date_approved' => Time.zone.now.iso8601,
        'date_created' => Time.zone.now.iso8601,
        'transaction_details' => { 'total_paid_amount' => '100.0' }
      }
    end

    let(:rejected_response) do
      approved_response.merge('status' => 'rejected')
    end

    before do
      mp_double = instance_double(Mercadopago::SDK)
      payment_double = instance_double(Mercadopago::Payment)
      allow(Mercadopago::SDK).to receive(:new).and_return(mp_double)
      allow(mp_double).to receive(:payment).and_return(payment_double)
      allow(payment_double).to receive(:get).with('12345')
                                            .and_return({ response: response_data })
    end

    context 'when payment is approved' do
      let(:response_data) { approved_response }

      it 'marks the grupo as pagado' do
        described_class.perform_now('12345')
        expect(grupo.reload.pagado?).to be(true)
      end
    end

    context 'when payment is rejected' do
      let(:response_data) { rejected_response }

      it 'keeps the grupo as abierto' do
        described_class.perform_now('12345')
        expect(grupo.reload.abierto?).to be(true)
      end
    end

    context 'when external_reference is blank' do
      let(:response_data) { { 'external_reference' => nil, 'status' => 'approved' } }

      it 'returns early without error' do
        expect { described_class.perform_now('12345') }.not_to raise_error
      end
    end

    # Regression: imputar_pago / desimputar_pago previously parsed
    # external_reference assuming "{pid}-{uid}" (count == 2). For multi-pedido
    # payments the format is "multiple-{grupo_id}-{uid}" (count == 3), which
    # made `user = nil` and then `user.operador?` raised NoMethodError, silently
    # crashing the entire webhook job for any group that actually had pedidos.
    context 'when grupo has pedidos and payment is approved' do
      let(:response_data) do
        approved_response.merge('order' => { 'id' => 1234 })
      end

      let!(:pedido) do
        p = Pedidos::Pedido.new(tienda: tienda, cuenta: cuenta, autor: usuario,
                                usuario: usuario, fecha: Date.current,
                                estado_id: 1, pedido_multiple_id: grupo.id)
        p.save!(validate: false)
        p
      end

      it 'parses the multi external_reference and reaches imputar_pago (no NoMethodError)' do
        # Regression: parser previously assumed "{pid}-{uid}" (count == 2) and
        # produced user=nil for multi payments ("multiple-{grupo_id}-{uid}"),
        # which made `user.operador?` blow up. We stub productos_solicitados
        # to bypass the empty? guard so imputar_pago is actually invoked,
        # then assert it was reached without NoMethodError.
        allow_any_instance_of(Pedidos::Pedido).to receive(:productos_solicitados).and_return([double(:ps)])
        expect_any_instance_of(Pedidos::Pedido).to receive(:imputar_pago).with(hash_including('status' => 'approved'))
        expect { described_class.perform_now('12345') }.not_to raise_error
      end
    end

    # Regression for MP $14,820 incident (2026-05-17): if ANY pedido in a group
    # raises during imputar_pago, the grupo must NOT be marked pagado and the
    # job must re-raise so DelayedJob retries. Previously the rescue caught
    # only RecordInvalid and the grupo was marked pagado BEFORE the loop,
    # leaving the payment orphaned on retry.
    context 'when one pedido in the grupo raises during imputar_pago' do
      let(:response_data) { approved_response.merge('order' => { 'id' => 1234 }) }
      let!(:pedido) do
        p = Pedidos::Pedido.new(tienda: tienda, cuenta: cuenta, autor: usuario,
                                usuario: usuario, fecha: Date.current,
                                estado_id: 1, pedido_multiple_id: grupo.id)
        p.save!(validate: false)
        p
      end

      before do
        allow_any_instance_of(Pedidos::Pedido).to receive(:productos_solicitados).and_return([double(:ps)])
        allow_any_instance_of(Pedidos::Pedido).to receive(:imputar_pago).and_raise(StandardError, 'boom')
        allow(ExceptionNotifier).to receive(:notify_exception)
      end

      it 'does NOT mark the grupo as pagado' do
        expect { described_class.perform_now('12345') }.to raise_error(StandardError)
        expect(grupo.reload.pagado?).to be(false)
      end

      it 'notifies via ExceptionNotifier with context' do
        expect(ExceptionNotifier).to receive(:notify_exception).with(
          instance_of(StandardError),
          hash_including(data: hash_including(:payment_id, :grupo_id, :pedido_id))
        )
        expect { described_class.perform_now('12345') }.to raise_error(StandardError)
      end

      it 're-raises so DelayedJob retries' do
        expect { described_class.perform_now('12345') }.to raise_error(StandardError, /boom/)
      end
    end
  end
end
