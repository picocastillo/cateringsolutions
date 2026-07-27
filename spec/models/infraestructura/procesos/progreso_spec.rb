require 'rails_helper'

RSpec.describe Infraestructura::Procesos::Progreso, type: :model do
  let(:progresable) { tienda }
  let(:tienda) { create(:tienda) }

  describe 'associations' do
    it { is_expected.to belong_to(:progresable) }
  end

  describe 'serialization' do
    it 'serializes errores as Array' do
      progreso = described_class.create!(progresable: progresable)
      progreso.errores = ['error1', 'error2']
      progreso.save!
      progreso.reload
      expect(progreso.errores).to eq ['error1', 'error2']
    end

    it 'handles legacy YAML-serialized errores gracefully' do
      progreso = described_class.create!(progresable: progresable)
      ActiveRecord::Base.connection.execute(
        "UPDATE progresos SET errores = '---' WHERE id = #{progreso.id}"
      )
      progreso.reload
      expect(progreso.error?).to be false
    end
  end

  describe '#start' do
    it 'initializes progress tracking' do
      progreso = described_class.create!(progresable: progresable)
      progreso.start(100)

      expect(progreso.actual).to eq 0
      expect(progreso.total).to eq 100
      expect(progreso.fecha_inicio).to be_within(5.seconds).of(Time.current)
      expect(progreso.fecha_fin).to be_nil
      expect(progreso.errores).to eq []
    end
  end

  describe '#finish' do
    it 'marks progress as complete' do
      progreso = described_class.create!(progresable: progresable)
      progreso.start(100)
      progreso.finish

      expect(progreso.actual).to eq 100
      expect(progreso.fecha_fin).to be_within(5.seconds).of(Time.current)
    end
  end

  describe '#finish_with_error' do
    it 'adds error and finishes' do
      progreso = described_class.create!(progresable: progresable)
      progreso.start(100)
      progreso.finish_with_error('Test error')

      expect(progreso.errores).to include('Test error')
      expect(progreso.fecha_fin).to be_present
    end
  end

  describe '#cancelar' do
    it 'marks progress as canceled' do
      progreso = described_class.create!(progresable: progresable)
      progreso.start(100)
      progreso.cancelar

      expect(progreso.fecha_fin).to be_within(5.seconds).of(Time.current)
      expect(progreso.cancelado).to be true
    end
  end

  describe '#pje' do
    it 'returns 0 when total is zero and not finished' do
      progreso = described_class.new(actual: 0, total: 0, fecha_inicio: Time.current, fecha_fin: nil)
      expect(progreso.pje).to eq 0
    end

    it 'returns 100 when total is zero and finished' do
      progreso = described_class.new(actual: 0, total: 0, fecha_inicio: Time.current, fecha_fin: Time.current)
      expect(progreso.pje).to eq 100
    end

    it 'calculates percentage correctly' do
      progreso = described_class.new(actual: 50, total: 100)
      expect(progreso.pje).to eq 50
    end

    it 'caps percentage at 100' do
      progreso = described_class.new(actual: 150, total: 100)
      expect(progreso.pje).to eq 100
    end
  end

  describe '#avanzar' do
    it 'increments actual count' do
      progreso = described_class.create!(progresable: progresable)
      progreso.start(100)
      progreso.avanzar

      expect(progreso.actual).to eq 1
    end

    it 'does not exceed total' do
      progreso = described_class.create!(progresable: progresable)
      progreso.start(2)
      progreso.avanzar
      progreso.avanzar
      progreso.avanzar

      expect(progreso.actual).to eq 2
    end
  end

  describe '#empezo?' do
    it 'returns true when started' do
      progreso = described_class.new(fecha_inicio: Time.current, actual: 1)
      expect(progreso.empezo?).to be true
    end

    it 'returns false when not started' do
      progreso = described_class.new(fecha_inicio: nil, actual: 0)
      expect(progreso).not_to be_empezo
    end
  end

  describe '#termino?' do
    it 'returns true when finished' do
      progreso = described_class.new(fecha_inicio: Time.current, fecha_fin: Time.current)
      expect(progreso).to be_termino
    end

    it 'returns false when not finished' do
      progreso = described_class.new(fecha_inicio: Time.current, fecha_fin: nil)
      expect(progreso).not_to be_termino
    end
  end

  describe '#ejecutando?' do
    it 'returns true when in progress' do
      progreso = described_class.new(fecha_inicio: Time.current, fecha_fin: nil, actual: 1, errores: [])
      expect(progreso.ejecutando?).to be true
    end

    it 'returns false when finished' do
      progreso = described_class.new(fecha_inicio: Time.current, fecha_fin: Time.current, actual: 1, errores: [])
      expect(progreso.ejecutando?).to be false
    end

    it 'returns false when has errors' do
      progreso = described_class.new(fecha_inicio: Time.current, fecha_fin: nil, actual: 1, errores: ['error'])
      expect(progreso.ejecutando?).to be false
    end
  end

  describe '#error?' do
    it 'returns true when has errors' do
      progreso = described_class.new(errores: ['error'])
      expect(progreso.error?).to be true
    end

    it 'returns false when no errors' do
      progreso = described_class.new(errores: [])
      expect(progreso.error?).to be false
    end
  end

  describe '#add_error' do
    it 'adds error to array' do
      progreso = described_class.new(errores: [])
      progreso.add_error('Test error')
      expect(progreso.errores).to include('Test error')
    end

    it 'truncates long errors to 60000 chars' do
      progreso = described_class.new(errores: [])
      long_error = 'a' * 70_000
      progreso.add_error(long_error)
      expect(progreso.errores.first.length).to eq 60_000
    end
  end

  describe '#estado' do
    it 'returns Cancelado when canceled' do
      progreso = described_class.new(cancelado: true)
      expect(progreso.estado).to eq 'Cancelado'
    end

    it 'returns Error when has errors' do
      progreso = described_class.new(cancelado: false, errores: ['error'])
      expect(progreso.estado).to eq 'Error'
    end

    it 'returns Finalizado when finished' do
      progreso = described_class.new(cancelado: false, errores: [], fecha_inicio: Time.current, fecha_fin: Time.current)
      expect(progreso.estado).to eq 'Finalizado'
    end

    it 'returns Pendiente when not started' do
      progreso = described_class.new(cancelado: false, errores: [], fecha_inicio: nil)
      expect(progreso.estado).to eq 'Pendiente'
    end

    it 'returns Ejecutando when in progress' do
      progreso = described_class.new(cancelado: false, errores: [], fecha_inicio: Time.current, fecha_fin: nil, actual: 1)
      expect(progreso.estado).to eq 'Ejecutando'
    end
  end

  describe '#pendiente?' do
    it 'returns true when state is Pendiente' do
      progreso = described_class.new(fecha_inicio: nil)
      expect(progreso.pendiente?).to be true
    end

    it 'returns false when state is not Pendiente' do
      progreso = described_class.new(fecha_inicio: Time.current, fecha_fin: Time.current)
      expect(progreso.pendiente?).to be false
    end
  end

  describe '#eta' do
    it 'returns nil when not started' do
      progreso = described_class.new(fecha_inicio: nil)
      expect(progreso.eta).to be_nil
    end

    it 'calculates estimated time of arrival' do
      progreso = described_class.new(
        fecha_inicio: 2.minutes.ago,
        actual: 50,
        total: 100
      )
      eta = progreso.eta
      expect(eta).to be > Time.current
      expect(eta).to be < 5.minutes.from_now
    end
  end

  describe '#track' do
    it 'runs block and tracks progress' do
      progreso = described_class.create!(progresable: progresable)
      result = progreso.track(100) do
        'result'
      end

      expect(result).to eq 'result'
      expect(progreso.fecha_inicio).to be_present
      expect(progreso.fecha_fin).to be_present
    end
  end
end
