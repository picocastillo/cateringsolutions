require 'rails_helper'

RSpec.describe Cobros::CobrosHelper, type: :helper do
  let(:user) { double('User') }
  let(:current_user) { user }

  before do
    allow(helper).to receive_messages(current_user: current_user, can?: true)
  end

  describe '#acciones_recibo' do
    let(:recibo) { double('Recibo', to_s: 'Recibo X 123') }
    let(:estado) { double('Estado', finalizado?: false) }

    before do
      allow(recibo).to receive_messages(estado: estado, disparable?: false)
      allow(helper).to receive_messages(anular_admin_recibo_path: '/recibos/1/anular', edit_admin_recibo_path: '/recibos/1/edit')
    end

    it 'returns array with edit link' do
      result = helper.acciones_recibo(recibo)
      expect(result).to be_an(Array)
      expect(result).not_to be_empty
    end

    it 'includes anular link when disparable for anular' do
      allow(recibo).to receive(:disparable?).with(
        Logistica::Flujos::EventosFlujos::Anular, current_user
      ).and_return(true)

      result = helper.acciones_recibo(recibo)
      expect(result.size).to eq(2)
    end

    it 'includes edit link when not finalized' do
      result = helper.acciones_recibo(recibo)
      expect(result).to include(match(/Editar/))
    end

    it 'includes continuar afectacion link when disparable' do
      allow(recibo).to receive(:disparable?).with(
        Logistica::Flujos::EventosFlujos::ContinuarAfectacion, current_user
      ).and_return(true)

      result = helper.acciones_recibo(recibo)
      expect(result).to include(match(/Continuar Afectación/))
    end
  end

  describe '#acciones_pago' do
    let(:pago) { double('Pago', to_s: 'Pago 123') }
    let(:estado) { double('Estado', finalizado?: false) }

    before do
      allow(pago).to receive_messages(estado: estado, disparable?: false)
      allow(helper).to receive_messages(anular_admin_pago_path: '/pagos/1/anular', edit_admin_pago_path: '/pagos/1/edit')
    end

    it 'returns array of links' do
      result = helper.acciones_pago(pago)
      expect(result).to be_an(Array)
    end

    it 'includes edit link when not finalized' do
      result = helper.acciones_pago(pago)
      expect(result).to include(match(/Editar/))
    end
  end

  describe '#preparar_afectaciones_pago' do
    let(:cuenta) { double('Cuenta') }
    let(:pago) { double('Pago', cuenta: cuenta, afectaciones: [], valid?: true) }
    let(:comprobante1) { double('Comprobante', saldo: 100, fecha_vencimiento: Time.zone.today, descripcion: 'Comp 1') }
    let(:comprobante2) { double('Comprobante', saldo: 200, fecha_vencimiento: Time.zone.today + 1, descripcion: 'Comp 2') }
    let(:afectado) { double('Afectado', fecha_vencimiento: Time.zone.today, descripcion: 'Test') }
    let(:afectacion) { double('Afectacion', afectado: afectado, created_at: Time.current, 'seleccionado=': true) }

    before do
      allow(pago.afectaciones).to receive(:each).and_yield(afectacion)
      allow(pago.afectaciones).to receive_messages(build: afectacion, detect: nil, to_a: [afectacion])
      allow(Ventas::Facturacion::Comprobante).to receive(:pendientes_para_pagar).and_return([comprobante1, comprobante2])
    end

    it 'returns the pago' do
      result = helper.preparar_afectaciones_pago(pago)
      expect(result).to eq(pago)
    end

    it 'sets seleccionado to true on existing afectaciones' do
      expect(afectacion).to receive(:seleccionado=).with(true)
      helper.preparar_afectaciones_pago(pago)
    end
  end
end
