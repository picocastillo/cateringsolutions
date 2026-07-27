class BigDecimal
  [:==, :<=>].each do |method|
    old = instance_method(method)
    define_method(method) do |other|
      other = BigDecimal(other.to_s) if !other.is_a?(BigDecimal) && other.is_a?(Numeric)
      old.bind_call(self, other)
    end
  end

  delegate :pretty, to: :to_f
end

class Float
  def to_graduacion
    format('%+.2f', self)
  end

  def pretty
    return '∞' if self == Float::INFINITY

    self == round ? round.to_s : to_s
  end

  def to_precision_range(umbral = 0.001)
    (self - umbral)..(self + umbral)
  end
end

class Integer
  def pretty
    to_s
  end

  def in_cents
    0
  end
end

class NilClass
  def pretty
    ''
  end

  def zero? = true
  def nonzero? = false

  def to_d
    0.0
  end
end

class Numeric
  def safe_divide(den)
    num = self
    if num.zero? && den.zero?
      0
    elsif den.zero?
      Float::INFINITY
    else
      num / den
    end
  end
end
