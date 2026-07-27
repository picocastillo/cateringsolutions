module Infraestructura
  module Procesos
    class Proceso < ApplicationRecord
      extend Memoist
      include Progresable

      belongs_to :autor, class_name: 'Usuarios::Usuario'
      belongs_to :tienda, class_name: 'Tiendas::Tienda'
      has_attached_file :adjunto, url: '/system/procesos/:hash/:filename'
      serialize :params, coder: YAML
      validate :debe_elegir_planilla_a_importar, if: :importar?
      after_destroy :destroy_job

      delegate :ejecutando?, :pendiente?, :error?, :error!, :cancelado?, :errores, :estado, :empezo?, to: :progreso

      def self.new_of_type(type, attrs)
        type.constantize.new attrs
      end

      def job
        Delayed::Job.where('handler like ?', "%gid://vtol/#{type}/#{id}%").last
      end
      memoize :job

      def puesto_actual
        Delayed::Job.where("id < #{job.id} and queue = '#{job.queue}' and last_error is null").count if job
      end
      memoize :puesto_actual

      def adjuntado_y_terminado?
        adjunto.exists? && progreso.termino?
      end

      def preparar_adjunto(filename)
        update adjunto_file_name: filename
        FileUtils.mkdir_p File.dirname adjunto.path
      end

      def kill
        progreso.add_error 'Job killed'
        progreso.cancelar
      end

      def codigo
        "##{id}"
      end

      def to_s
        "#{human_name} #{codigo}"
      end

      def self.purgar_antiguos
        where(created_at: ...1.year.ago).find_each(batch_size: 100, &:destroy)
      end

      private

      def debe_elegir_planilla_a_importar
        errors.add :adjunto, '^Por favor seleccione el archivo a importar' unless adjunto?
      end

      def destroy_job
        job&.destroy
      end
    end
  end
end
