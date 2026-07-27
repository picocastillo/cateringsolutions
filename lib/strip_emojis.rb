class StripEmojis
  def initialize(attribute)
    @attribute = attribute
  end

  def before_validation(object)
    object.send "#{@attribute}=", strip_emoji(object.send(@attribute))
  end

  private

  def strip_emoji(text)
    return unless text

    text = text.force_encoding('utf-8').encode

    # symbols & pics
    regex = /[\u{1f300}-\u{1f5ff}]/
    clean = text.gsub regex, ''

    # enclosed chars
    regex = /[\u{2500}-\u{2BEF}]/ # I changed this to exclude chinese char
    clean = clean.gsub regex, ''

    # emoticons
    regex = /[\u{1f600}-\u{1f64f}]/
    clean = clean.gsub regex, ''

    # dingbats
    regex = /[\u{2702}-\u{27b0}]/
    clean.gsub regex, ''
  end
end
