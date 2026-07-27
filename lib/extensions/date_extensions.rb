class Date
  def months_until(to)
    from = self
    m = Date.new from.year, from.month
    result = []
    while m <= to
      result << m
      m >>= 1
    end
    result
  end

  def months_qty(to)
    ((to.year * 12) + to.month) - ((year * 12) + month) + 1
  end

  def self.months_qty(from, to)
    from = (from.presence && from.respond_to?(:to_date) && begin
      from.to_date
    rescue StandardError
      nil
    end) || Date.new(1900, 1, 1)
    to = (to.presence && to.respond_to?(:to_date) && begin
      to.to_date
    rescue StandardError
      nil
    end) || Time.zone.today
    from.months_qty to
  end

  def to_formatted_s(format = :default)
    formats = ::Date::DATE_FORMATS.merge I18n.t 'date.formats'
    formatter = formats[format]
    format_to_localize = formatter.respond_to?(:call) ? formatter.call(self) : formatter
    I18n.l(self, format: format_to_localize)
  end
  alias to_s to_formatted_s

  class << self
    alias euro_parse _parse
    def _parse(str, comp = false)
      str = str.to_s.strip
      return {} if str == ''

      if str =~ %r{^(\d{1,2})[-/](\d{1,2})[-/](\d+)}
        year = ::Regexp.last_match(3).to_i
        month = ::Regexp.last_match(2)
        day = ::Regexp.last_match(1)
        _, *rest = str.split
        year += (year < 35 ? 2000 : 1900) if year < 100
        euro_parse("#{year}-#{month}-#{day} #{rest.join(' ')}", comp)
      else
        euro_parse(str, comp)
      end
    end

    module ParseWithI18n
      def parse(str, format = :default)
        format ||= :default
        date = Date.strptime(translate_month_and_day_names(str), I18n.t("date.formats.#{format}"))
        Date.new(date.year + increment_year(date.year), date.month, date.day)
      rescue ArgumentError
        super
      end
    end
    prepend ParseWithI18n

    private

    def increment_year(year)
      if year < 100
        year < 30 ? 2000 : 1900
      else
        0
      end
    end

    def translate_month_and_day_names(date)
      date = date.dup
      translated = I18n.t([:month_names, :abbr_month_names, :day_names, :abbr_day_names],
                          scope: :date).flatten.compact
      original = (Date::MONTHNAMES + Date::ABBR_MONTHNAMES + Date::DAYNAMES + Date::ABBR_DAYNAMES).compact
      translated.each_with_index { |name, i| date.gsub!(/#{name}/i, original[i]) }
      date
    end
  end
end
