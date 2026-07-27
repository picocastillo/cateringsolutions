class FalseClass
  def to_sino
    'No'
  end

  def boolean?
    true
  end
end

class TrueClass
  def to_sino
    'Si'
  end

  def boolean?
    true
  end
end

class NilClass
  def to_sino
    'No'
  end
end

module Kernel
  def Boolean(string) # rubocop:disable Naming/MethodName
    return true if string == true
    return false if string == false || string.nil?
    return true if string.respond_to?(:=~) && string =~ /(true|t|yes|y|1|si)$/i
    return false if string.blank? || (string.respond_to?(:=~) && string =~ /(false|f|no|n|0)$/i)

    raise ArgumentError, "invalid value for Boolean: \"#{string}\""
  end
end

class Object
  def boolean?
    false
  end
end
