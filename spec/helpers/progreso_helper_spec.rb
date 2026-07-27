require 'rails_helper'

RSpec.describe ProgresoHelper, type: :helper do
  describe '#eta' do
    it 'returns duration for terminated progress' do
      progreso = double('Progreso',
                        termino?: true,
                        fecha_inicio: 1.hour.ago,
                        fecha_fin: Time.current)

      result = helper.eta(progreso)
      expect(result).to include('hora')
    end

    it 'returns time until eta for running progress' do
      progreso = double('Progreso',
                        termino?: false,
                        eta: 30.minutes.from_now)

      result = helper.eta(progreso)
      expect(result).to include('minuto')
    end

    it 'returns default message when no eta available' do
      progreso = double('Progreso',
                        termino?: false,
                        eta: nil)

      expect(helper.eta(progreso)).to eq 'Iniciará en instantes'
    end
  end

  describe '#link_to_errores' do
    it 'returns nil when progreso has no errors' do
      progreso = double('Progreso', errores: nil)
      expect(helper.link_to_errores(progreso)).to be_nil
    end

    it 'returns nil when progreso has blank errors' do
      progreso = double('Progreso', errores: [])
      expect(helper.link_to_errores(progreso)).to be_nil
    end

    it 'generates modal and link when errors present' do
      progreso = double('Progreso', errores: ['Error 1', 'Error 2'])
      allow(helper).to receive(:dom_id).with(progreso).and_return('progreso_1')
      allow(helper).to receive_messages(modal: '<div class="modal"></div>'.html_safe, link_to_function: '<a>Errores</a>'.html_safe)

      result = helper.link_to_errores(progreso)
      expect(result).to be_present
    end
  end

  describe '#estado_proceso' do
    it 'shows percentage for running process' do
      progreso = double('Progreso', pje: 45.5)
      proceso = double('Proceso', ejecutando?: true, progreso: progreso, estado: 'Ejecutando')

      result = helper.estado_proceso(proceso)
      expect(result).to include('46%')
      expect(result).to include('label')
    end

    it 'shows estado for non-running process' do
      proceso = double('Proceso', ejecutando?: false, estado: 'Finalizado')

      result = helper.estado_proceso(proceso)
      expect(result).to include('Finalizado')
      expect(result).to include('label')
    end
  end

  describe '#eta_proceso' do
    it 'returns generating message when generating file' do
      proceso = double('Proceso', generando_archivo?: true)
      expect(helper.eta_proceso(proceso)).to eq 'Generando archivo...'
    end

    it 'returns eta when process has started' do
      progreso = double('Progreso',
                        termino?: false,
                        eta: 10.minutes.from_now)
      proceso = double('Proceso',
                       generando_archivo?: false,
                       empezo?: true,
                       progreso: progreso)

      result = helper.eta_proceso(proceso)
      expect(result).to include('minuto')
    end

    it 'returns queue position when process not started' do
      proceso = double('Proceso',
                       generando_archivo?: false,
                       empezo?: false,
                       puesto_actual: 3)

      expect(helper.eta_proceso(proceso)).to eq '3º en cola de espera'
    end
  end

  describe '#label_segun_estado' do
    it 'returns warning label for pendiente' do
      proceso = double('Proceso', estado: 'Pendiente')
      expect(helper.label_segun_estado(proceso)).to eq 'label-warning'
    end

    it 'returns info label for ejecutando' do
      proceso = double('Proceso', estado: 'Ejecutando')
      expect(helper.label_segun_estado(proceso)).to eq 'label-info'
    end

    it 'returns success label for finalizado' do
      proceso = double('Proceso', estado: 'Finalizado')
      expect(helper.label_segun_estado(proceso)).to eq 'label-success'
    end

    it 'returns important label for error' do
      proceso = double('Proceso', estado: 'Error')
      expect(helper.label_segun_estado(proceso)).to eq 'label-important'
    end

    it 'returns important label for cancelado' do
      proceso = double('Proceso', estado: 'Cancelado')
      expect(helper.label_segun_estado(proceso)).to eq 'label-important'
    end
  end
end
