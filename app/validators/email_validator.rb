class EmailValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    return if value.blank?

    if options[:multiple]
      emails = value.split(',').map(&:strip)
      record[attribute] = emails.join ', '
      invalidos = emails.reject { |email| valid_email? email }
      record.errors.add(attribute, "'#{invalidos.join(', ')}' no es una dirección de email válida") if invalidos.any?
    else
      record.errors.add(attribute, "'#{value}' no es una dirección de email válida") unless valid_email? value
    end
  end

  private

  def valid_email?(email)
    email.strip =~ /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\Z/i
  end
end
