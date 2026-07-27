module Infraestructura
  module Concerns
    module HasOneDocumento
      extend ActiveSupport::Concern

      included do
        has_one :documento, as: :documentable, dependent: :destroy, class_name: 'Infraestructura::Documento'
      end

      def documentos
        Array documento
      end

      def documento_ids=(ids)
        self.documento = Documento.find_by(id: ids.compact_blank.first)
      end
    end
  end
end
