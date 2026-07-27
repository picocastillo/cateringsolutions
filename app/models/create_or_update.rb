module CreateOrUpdate
  def create_or_update_by(field_or_fields, attributes)
    fields = Array field_or_fields
    conditions = attributes.slice(*fields)
    raise ArgumentError, "Attributes #{attributes.inspect} should contain the condition fields #{fields.inspect}" if conditions.empty?

    find_or_initialize_by(conditions).tap do |record|
      record.update! attributes
    end
  end

  def create_or_update(attributes)
    create_or_update_by :id, attributes
  end
end
