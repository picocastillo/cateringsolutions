module KIOSK
  module CollectionAssociationWithHashes
    def replace(other_array)
      other_array = other_array.map do |record|
        record.is_a?(Hash) ? @reflection.klass.new(record) : record
      end
      super
    end
  end

  module HasOneAssociationWithHash
    def replace(record, save = true)
      record = @reflection.klass.new(record) if record.is_a?(Hash)
      super
    end
  end

  module BelongsToAssociationWithHash
    def replace(record)
      record = @reflection.klass.new(record) if record.is_a?(Hash)
      super
    end
  end
end

ActiveRecord::Associations::CollectionAssociation.prepend KIOSK::CollectionAssociationWithHashes
ActiveRecord::Associations::HasOneAssociation.prepend KIOSK::HasOneAssociationWithHash
ActiveRecord::Associations::BelongsToAssociation.prepend KIOSK::BelongsToAssociationWithHash
