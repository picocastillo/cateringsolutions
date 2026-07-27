# Define DANCONIA_MONEY globally for use in YAML/Psych patches and custom coders
begin
  require 'danconia/money'
  require 'danconia/integrations/active_record'
  DANCONIA_MONEY = Danconia::Money
rescue LoadError, NameError
  DANCONIA_MONEY = nil
end
