class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  extend CreateOrUpdate
  extend Lazy
  extend SerializeIds
  extend OnConstMissingDetection
  extend Defaults
  include Cloning

  def self.alias_accessor(new_name, orig_name)
    class_eval %{
      def #{new_name}() #{orig_name} end
      def #{new_name}=(value) self.#{orig_name} = value end
    }, __FILE__, __LINE__ - 3
  end

  def self.cache_key
    max = maximum(:updated_at)
    [table_name, max.to_fs(:number)].join('-') if max
  end

  def to_base
    base_class = self.class
    base_class = base_class.superclass until base_class.superclass == ApplicationRecord
    becomes(base_class)
  end

  def human_name
    self.class.model_name.human
  end

  def type_and_id
    "#{self.class.name}|#{id}"
  end
end
