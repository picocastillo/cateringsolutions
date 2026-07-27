# Rails 7.1 compatible extensions
module ActiveRecord
  module Associations
    class CollectionProxy
      # Esto hace que al usar el lock en test no acceda a la base
      module DontLockIfOwnerIsNewRecord
        def lock(*args)
          return self if proxy_association.owner.new_record?

          super
        end
      end
      prepend DontLockIfOwnerIsNewRecord

      # El delete_if es delegado a Array y por lo tanto no lo quita de la base
      def destroy_if(&)
        select(&).map { |record| delete record }
      end
    end
  end
end

# Por defecto la búsqueda era case sensitive
module ActiveRecord
  module Validations
    class UniquenessValidator
      module CaseInsensitiveByDefault
        def initialize(options)
          super(options.reverse_merge(case_sensitive: false))
        end
      end
      prepend CaseInsensitiveByDefault
    end
  end
end
