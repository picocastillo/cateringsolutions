# Suppress specific deprecation warnings
# This suppresses various gem deprecation warnings that clutter the output

if defined?(Warning) && Warning.respond_to?(:[]=)
  # Suppress specific deprecation warnings
  original_warn = Warning.method(:warn)
  Warning.define_singleton_method(:warn) do |message|
    # Skip warnings we want to suppress
    suppressed_warnings = [
      'rb_safe_level will be removed in Ruby 3.0',
      "control_d_handler's arity of 2 parameters was deprecated"
    ]

    return if suppressed_warnings.any? { |warning| message.include?(warning) }

    original_warn.call(message)
  end
end
