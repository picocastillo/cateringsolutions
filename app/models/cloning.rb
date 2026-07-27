module Cloning
  NON_CONTENT_ATTRIBUTES = ['id', 'type', 'created_at', 'updated_at'].freeze

  def clonar(options = {})
    exclude_attributes = default_excluded_attributes options
    shallow_attributes = attribute_names + default_shallow_associations(options) - exclude_attributes
    deep_copy_attributes = default_deep_copy_associations(options) - exclude_attributes
    self.class.new.copy_fields_from(self, shallow_attributes).tap do |clon|
      deep_copy_attributes.each do |method|
        self_assoc_value = send(method)
        associated_clone = self_assoc_value.respond_to?(:each) ? self_assoc_value.map(&:clonar) : self_assoc_value.try(:clonar)
        clon.send :"#{method}=", associated_clone
      end
    end
  end

  def copy_fields_from(other, fields = other.attribute_names)
    (fields - NON_CONTENT_ATTRIBUTES).each { |field| send :"#{field}=", other.send(field) }
    self
  end

  private

  def default_excluded_attributes(options)
    excluded = Array(options[:except]).map(&:to_s)
    if excluded.any?
      excluded.concat self.class.reflections.select { |name, r|
        r.macro == :belongs_to && excluded.include?(name.to_s)
      }.values.map(&:foreign_key)
    end
    excluded
  end

  def default_shallow_associations(options)
    options[:shallow] ||= self.class.reflections.select { |_, r| r.macro == :belongs_to }.keys.map(&:to_s)
    Array(options[:shallow])
  end

  def default_deep_copy_associations(options)
    Array(options[:deep_copy]).map(&:to_s)
  end
end
