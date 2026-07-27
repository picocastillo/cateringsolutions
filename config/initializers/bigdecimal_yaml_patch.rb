# Patch BigDecimal to always be serializable to YAML
require 'bigdecimal'
require 'yaml'

class BigDecimal
  def to_yaml(opts = {})
    Psych.dump(to_s('F'), **opts)
  end
end

# Patch Danconia::Money if present
if defined?(DANCONIA_MONEY) && DANCONIA_MONEY
  DANCONIA_MONEY.class_eval do
    def to_yaml(opts = {})
      Psych.dump(to_s, **opts)
    end
  end
end
