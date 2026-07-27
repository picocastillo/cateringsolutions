class WithinValidator < ActiveModel::Validations::InclusionValidator
  def initialize(options = {})
    options[:message] ||= "debe estar entre #{options[:in].first} y #{options[:in].last}"
    super
  end
end
