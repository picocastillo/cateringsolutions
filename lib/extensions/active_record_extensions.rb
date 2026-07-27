module ActiveRecord
  class Base
    NON_CONTENT_ATTRIBUTES = ['id', 'type', 'created_at', 'updated_at'].freeze

    def content_attributes
      attributes.except(*NON_CONTENT_ATTRIBUTES)
    end

    def self.find_for_autocomplete(params)
      where('codigo = ? or nombre like ?', params[:q], "%#{params[:q]}%").limit params[:limit]
    end

    def id_compuesto
      "#{id}_#{self.class.name}"
    end
  end
end

module ActiveRecord
  module Associations
    class CollectionProxy
      # El delete_if es delegado a Array y por lo tanto no lo quita de la base
      def destroy_if(&)
        select(&).map { |record| delete record }
      end

      def preserved
        reject &:marked_for_destruction?
      end
    end
  end
end
