require 'rails_helper'

RSpec.describe Clientes::ConfirmarJob, type: :job do
  describe 'inheritance' do
    it 'inherits from ApplicationJob' do
      expect(described_class.superclass).to eq ApplicationJob
    end
  end

  describe 'queue configuration' do
    it 'is queued as :confirmacion' do
      expect(described_class.queue_name).to eq 'confirmacion'
    end
  end

  describe '#perform' do
    let(:tienda) { create(:tienda) }
    let(:pedido) { create(:pedido, tienda: tienda) }

    context 'when pedido is already confirmed' do
      before do
        allow_any_instance_of(Pedidos::Pedido).to receive(:confirmado?).and_return(true)
      end

      it 'returns early without doing anything' do
        expect_any_instance_of(Pedidos::Pedido).not_to receive(:confirmar!)
        expect_any_instance_of(Pedidos::Pedido).not_to receive(:destroy!)

        described_class.new.perform(pedido.id)
      end
    end

    context 'when pedido is not confirmed' do
      before do
        allow_any_instance_of(Pedidos::Pedido).to receive(:confirmado?).and_return(false)
      end

      context 'and has productos_solicitados' do
        before do
          allow_any_instance_of(Pedidos::Pedido).to receive(:productos_solicitados).and_return([double('producto')])
        end

        it 'confirms the pedido' do
          expect_any_instance_of(Pedidos::Pedido).to receive(:confirmar!)
          described_class.new.perform(pedido.id)
        end
      end

      context 'and has no productos_solicitados' do
        before do
          allow_any_instance_of(Pedidos::Pedido).to receive(:productos_solicitados).and_return([])
        end

        it 'logs error and destroys the pedido' do
          expect(Rails.logger).to receive(:error).with(/Eliminando pedido/)
          expect_any_instance_of(Pedidos::Pedido).to receive(:destroy!)

          described_class.new.perform(pedido.id)
        end
      end
    end

    context 'when pedido does not exist' do
      it 'raises ActiveRecord::RecordNotFound' do
        expect do
          described_class.new.perform(999_999)
        end.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end

  describe 'advisory lock' do
    let(:tienda) { create(:tienda) }
    let(:pedido) { create(:pedido, tienda: tienda) }

    it 'skips work when the advisory lock is already held by another connection' do
      lock_name = described_class.advisory_lock_name(pedido.id)

      # Acquire the lock on a separate DB connection so the job sees it as taken.
      holder_pool = ActiveRecord::Base.connection_pool
      holder_conn = holder_pool.checkout
      begin
        got = holder_conn.select_value("SELECT GET_LOCK(#{holder_conn.quote(lock_name)}, 0)").to_i
        expect(got).to eq(1), 'precondition: holder must acquire the lock'

        expect_any_instance_of(Pedidos::Pedido).not_to receive(:confirmar!)
        expect(Pedidos::Pedido).not_to receive(:find)

        described_class.new.perform(pedido.id)
      ensure
        holder_conn.select_value("SELECT RELEASE_LOCK(#{holder_conn.quote(lock_name)})")
        holder_pool.checkin(holder_conn)
      end
    end

    it 'releases the lock after a successful run' do
      allow_any_instance_of(Pedidos::Pedido).to receive(:confirmado?).and_return(true)

      described_class.new.perform(pedido.id)

      lock_name = described_class.advisory_lock_name(pedido.id)
      conn = ActiveRecord::Base.connection
      free = conn.select_value("SELECT IS_FREE_LOCK(#{conn.quote(lock_name)})").to_i
      expect(free).to eq(1)
    end

    it 'releases the lock when perform raises' do
      allow_any_instance_of(Pedidos::Pedido).to receive(:confirmado?).and_raise(StandardError, 'boom')

      expect { described_class.new.perform(pedido.id) }.to raise_error(StandardError, 'boom')

      lock_name = described_class.advisory_lock_name(pedido.id)
      conn = ActiveRecord::Base.connection
      free = conn.select_value("SELECT IS_FREE_LOCK(#{conn.quote(lock_name)})").to_i
      expect(free).to eq(1)
    end
  end
end
