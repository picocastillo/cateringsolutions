class DateValidator < ActiveModel::EachValidator
  # Implemented checks and their associated operators.
  CHECKS = { after: :>, after_or_equal_to: :>=,
             before: :<, before_or_equal_to: :<= }.freeze

  # Call `#initialize` on the superclass, adding a default
  # `allow_nil: false` option.
  def initialize(options)
    super(options.reverse_merge(allow_nil: false))
  end

  # Validates the arguments passed to the validator.
  #
  # They must be either any kind of Time, a Proc, or a Symbol.
  def check_validity!
    keys = CHECKS.keys
    options.slice(*keys).each do |option, value|
      next if is_time?(value) || value.is_a?(Proc) || value.is_a?(Symbol) || (defined?(ActiveSupport::TimeWithZone) && value.is_a?(ActiveSupport::TimeWithZone))

      raise ArgumentError, ":#{option} must be a time, a date, a time_with_zone, a symbol or a proc"
    end
  end

  # Overridden because standard allow_nil and allow_blank checks don't work with
  # string expressions that cannot be type cast to dates. We have to validate
  # the pre-type cast values.
  def validate(record)
    attributes.each do |attribute|
      value = record.read_attribute_for_validation(attribute)
      validate_each(record, attribute, value)
    end
  end

  # The actual validator method. It is called when ActiveRecord iterates
  # over all the validators.
  def validate_each(record, attr_name, value)
    before_type_cast = :"#{attr_name}_before_type_cast"

    value_before_type_cast = if record.respond_to?(before_type_cast)
                               record.send(before_type_cast)
                             else
                               value
                             end

    return if value_before_type_cast.blank? && options[:allow_nil]

    parsed_value = if value.present? && value.is_a?(String)
                     begin
                       Date.parse value # es necesario xq el to_time pasa igual para fechas invalidas como 31/9/2015
                       value.to_time
                     rescue StandardError
                       nil
                     end
                   else
                     value
                   end
    if parsed_value.blank?
      record.errors.add(attr_name, :not_a_date, **options)
      return
    end

    options.slice(*CHECKS.keys).each do |option, option_value|
      option_value = option_value.call(record) if option_value.is_a?(Proc)
      option_value = record.send(option_value) if option_value.is_a?(Symbol)

      original_value = value
      original_option_value = option_value

      # To enable to_i conversion, these types must be converted to Datetimes
      if defined?(ActiveSupport::TimeWithZone)
        option_value = option_value.to_datetime if option_value.is_a?(ActiveSupport::TimeWithZone)
        value = value.to_datetime if value.is_a?(ActiveSupport::TimeWithZone)
      end

      if defined?(Date)
        option_value = option_value.to_datetime if option_value.is_a?(Date)
        value = value.to_datetime if value.is_a?(Date)
      end

      next if is_time?(option_value) && value.to_i.send(CHECKS[option], option_value.to_i)

      record.errors.add(attr_name, option, **options, value: original_value,
                                                      date: begin
                                                        I18n.l(original_option_value)
                                                      rescue StandardError
                                                        original_option_value
                                                      end)
    end
  end

  private

  def is_time?(object)
    object.is_a?(Time) || (defined?(Date) and object.is_a?(Date)) || (defined?(ActiveSupport::TimeWithZone) and object.is_a?(ActiveSupport::TimeWithZone))
  end
end
