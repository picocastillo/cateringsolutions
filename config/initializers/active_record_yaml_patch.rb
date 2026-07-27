# Patch ActiveRecord YAMLColumn to always permit BigDecimal and Danconia::Money
require 'active_record'
require 'psych'
require 'yaml'
require 'bigdecimal'

if defined?(ActiveRecord::Coders::YAMLColumn)
  ActiveRecord::Coders::YAMLColumn.class_eval do
    alias_method :original_load, :load
    def load(yaml)
      return yaml if yaml.nil? || yaml == ''

      permitted = [BigDecimal, Symbol]
      permitted << DANCONIA_MONEY if defined?(DANCONIA_MONEY) && DANCONIA_MONEY
      Psych.safe_load(yaml, permitted_classes: permitted, aliases: true)
    end
  end
end
