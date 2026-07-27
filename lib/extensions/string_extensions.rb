class String
  def pluralize_with_count(count)
    "#{count || 0} " +
      if count == 1
        self
      elsif ActiveSupport.const_defined?('Inflector')
        ActiveSupport::Inflector.pluralize(self)
      else
        "#{self}s"
      end
  end

  def pluralize_without_count(count)
    count == 1 ? self : pluralize
  end

  TRANSLITERATION_TABLE = {
    'ÀÁÂÃÅĀĄĂ' => 'A', 'Ä' => 'Ae', 'àáâãåāąă' => 'a', 'ä' => 'ae',
    'Æ' => 'AE', 'æ' => 'ae', 'ÇĆČĈĊ' => 'C', 'çćčĉċ' => 'c',
    'ĎĐ' => 'D', 'ďđ' => 'd', 'ÈÉÊËĒĘĚĔĖ' => 'E', 'èéêëēęěĕė' => 'e',
    'ƒ' => 'f', 'ĜĞĠĢ' => 'G', 'ĝğġģ' => 'g', 'ĤĦ' => 'H', 'ĥħ' => 'h',
    'ÌÍÎÏĪĨĬĮİ' => 'I', 'ìíîïīĩĭįı' => 'i', 'Ĳ' => 'IJ', 'Ĵ' => 'J',
    'ĵ' => 'j', 'Ķ' => 'K', 'ķĸ' => 'k', 'ŁĽĹĻĿ' => 'L', 'łľĺļŀ' => 'l',
    'ÑŃŇŅŊ' => 'N', 'ñńňņŉŋ' => 'n', 'ÒÓÔÕØŌŐŎ' => 'O', 'Ö' => 'Oe',
    'òóôõøōőŏ' => 'o', 'ö' => 'oe', 'Œ' => 'OE', 'œ' => 'oe',
    'ŔŘŖ' => 'R', 'ŕřŗ' => 'r', 'ŚŠŞŜȘ' => 'S', 'śšşŝș' => 's',
    'ŤŢŦȚ' => 'T', 'ťţŧț' => 't', 'ÙÚÛŪŮŰŬŨŲ' => 'U', 'Ü' => 'Ue',
    'ùúûūůűŭũų' => 'u', 'ü' => 'ue', 'Ŵ' => 'W', 'ŵ' => 'w',
    'ÝŶŸ' => 'Y', 'ýÿŷ' => 'y', 'ŹŽŻ' => 'Z', 'žżź' => 'z'
  }.freeze
  def to_ascii
    dup.force_encoding('utf-8').tap do |str|
      TRANSLITERATION_TABLE.each do |key, value|
        str.gsub!(/[#{key}]/, value)
      end
    end
  end

  def sanitize
    to_ascii.strip_non_recognized_chars
  end

  def strip_non_recognized_chars
    gsub(/[^a-z._0-9 -]/i, '').tr('.', '_').gsub(/(\s+)/, '_').downcase
  end

  def split_csv
    split(',').map(&:strip).compact_blank
  end
end
