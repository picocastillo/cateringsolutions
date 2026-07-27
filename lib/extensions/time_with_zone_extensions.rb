class ActiveSupport::TimeWithZone
  def to_s(format = :default)
    return utc.to_s(format) if format == :db

    formats = ::Time::DATE_FORMATS
    formatter = formats[format]

    unless formatter
      default_formatters = begin
        I18n.t(:'time.formats', raise: true)
      rescue StandardError
        {}
      end
      twz_formatters = begin
        I18n.t(:'time.time_with_zone.formats', raise: true)
      rescue StandardError
        {}
      end
      formatters = default_formatters.merge(twz_formatters)
      formatter  = formatters[format]
    end

    format_to_localize = formatter.respond_to?(:call) ? formatter.call(self) : formatter
    I18n.l(self, format: format_to_localize)
  end
end
