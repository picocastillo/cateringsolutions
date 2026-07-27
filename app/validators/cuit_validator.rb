class CuitValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    return if value.blank? && options[:allow_nil]

    value = value.to_s.dup # Duplicate to avoid frozen string errors
    value.gsub!(/[^\d]/, '')
    record.errors.add(attribute, 'es inválido') unless cuit_valido? value
  end

  def cuit_valido?(value)
    valid = true
    valid &= value.size == 11 if value
    if valid && value.present?
      coefficients = [5, 4, 3, 2, 7, 6, 5, 4, 3, 2, 1]
      digits = value.gsub(/\D/, '').chars.collect(&:to_i)
      sum = digits.inject(0) { |s, digit| s + (digit * coefficients.shift) }
      valid = (sum % 11).zero?
    end
    valid
  end
end
