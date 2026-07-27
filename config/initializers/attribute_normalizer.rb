AttributeNormalizer.configure do |config|
  config.default_normalizers = :squish, :blank

  config.normalizers[:csv] = lambda { |value, _|
    return unless value.is_a?(String)

    value.split(',').map(&:strip).compact_blank.join(', ')
  }

  config.normalizers[:upcase] = lambda { |value, _|
    value.is_a?(String) ? value.upcase : value
  }
end
