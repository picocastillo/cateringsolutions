class DateTime
  def to_formatted_s(format = :default)
    time_formatters = begin
      I18n.t 'time.formats', raise: true
    rescue StandardError
      {}
    end
    datetime_formatters = begin
      I18n.t 'time.datetime.formats', raise: true
    rescue StandardError
      {}
    end
    formats = ::Time::DATE_FORMATS.merge(time_formatters).merge(datetime_formatters)
    formatter = formats[format]
    format_to_localize = formatter.respond_to?(:call) ? formatter.call(self) : formatter
    I18n.l(self, format: format_to_localize)
  end
  alias to_s to_formatted_s
end
