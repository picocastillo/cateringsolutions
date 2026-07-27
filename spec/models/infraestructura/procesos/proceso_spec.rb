require 'rails_helper'

RSpec.describe Infraestructura::Procesos::Proceso, type: :model do
  let(:tienda) { create(:tienda) }
  let(:usuario) { create(:usuario, :admin, visualizando_tienda: tienda) }

  def create_proceso(created_at: Time.current, finished: true)
    proceso = Productos::StocksExporter.new(
      autor: usuario,
      tienda: tienda,
      params: {}
    )
    proceso.save!

    if finished
      proceso.progreso.update!(
        actual: 100, total: 100,
        fecha_inicio: created_at,
        fecha_fin: created_at + 1.minute
      )
    end

    proceso.update_column(:created_at, created_at)
    proceso
  end

  describe '.purgar_antiguos' do
    it 'destroys procesos older than 1 year' do
      old_proceso = create_proceso(created_at: 13.months.ago)

      expect { described_class.purgar_antiguos }
        .to change(described_class, :count).by(-1)

      expect(described_class.find_by(id: old_proceso.id)).to be_nil
    end

    it 'destroys the associated progreso record' do
      old_proceso = create_proceso(created_at: 2.years.ago)
      progreso_id = old_proceso.progreso.id

      described_class.purgar_antiguos

      expect(Infraestructura::Procesos::Progreso.find_by(id: progreso_id)).to be_nil
    end

    it 'keeps procesos newer than 1 year' do
      recent_proceso = create_proceso(created_at: 6.months.ago)

      expect { described_class.purgar_antiguos }
        .not_to change(described_class, :count)

      expect(described_class.find_by(id: recent_proceso.id)).to be_present
    end

    it 'keeps procesos just under 1 year old' do
      borderline = create_proceso(created_at: 11.months.ago)

      expect { described_class.purgar_antiguos }
        .not_to change(described_class, :count)

      expect(described_class.find_by(id: borderline.id)).to be_present
    end

    it 'handles mix of old and recent procesos' do
      old1 = create_proceso(created_at: 14.months.ago)
      old2 = create_proceso(created_at: 2.years.ago)
      recent = create_proceso(created_at: 3.months.ago)

      expect { described_class.purgar_antiguos }
        .to change(described_class, :count).by(-2)

      expect(described_class.find_by(id: old1.id)).to be_nil
      expect(described_class.find_by(id: old2.id)).to be_nil
      expect(described_class.find_by(id: recent.id)).to be_present
    end
  end

  describe '#destroy' do
    it 'destroys the proceso and its progreso' do
      proceso = create_proceso

      expect { proceso.destroy }
        .to change(described_class, :count).by(-1)
        .and change(Infraestructura::Procesos::Progreso, :count).by(-1)
    end

    it 'destroys the associated delayed job if present' do
      proceso = create_proceso(finished: false)
      # Simulate a delayed job entry
      job = Delayed::Job.create!(
        handler: "--- !ruby/object:ActiveJob::QueueAdapters::DelayedJobAdapter::JobWrapper\njob_data:\n  job_class: Infraestructura::Procesos::LanzarProcesoJob\n  arguments:\n  - _aj_globalid: gid://vtol/#{proceso.type}/#{proceso.id}\n",
        queue: 'slow',
        run_at: Time.current
      )

      proceso.destroy

      expect(Delayed::Job.find_by(id: job.id)).to be_nil
    end

    it 'works when no delayed job exists' do
      proceso = create_proceso

      expect { proceso.destroy }.not_to raise_error
    end
  end
end
