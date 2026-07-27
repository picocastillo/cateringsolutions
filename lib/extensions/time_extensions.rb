class Time
  def months_until(to)
    to_date.months_until to.to_date
  end

  def to_formatted_s(format = :default)
    formats = ::Time::DATE_FORMATS.merge I18n.t 'time.formats'
    formatter = formats[format]
    format_to_localize = formatter.respond_to?(:call) ? formatter.call(self) : formatter
    I18n.l(self, format: format_to_localize)
  end
  alias to_s to_formatted_s

  def to_ms
    (to_f * 1000.0).to_i
  end
end
