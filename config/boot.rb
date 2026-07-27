# Ruby 3.x compatibility patch: ensure URI class variable exists before anything else
begin
  require 'uri'
  URI.class_variable_set(:@@schemes, {}) unless URI.class_variable_defined?(:@@schemes) # rubocop:disable Style/ClassVars
rescue LoadError
  # ignore
end

require 'logger'
require 'stringio'

# Suppress specific gem deprecation warnings
original_stderr = $stderr

class WarningFilter
  def initialize(original_stderr)
    @original_stderr = original_stderr
    @suppressed_warnings = [
      'rb_safe_level will be removed in Ruby 3.0',
      "control_d_handler's arity of 2 parameters was deprecated"
    ]
  end

  def write(message)
    return if @suppressed_warnings.any? { |warning| message.include?(warning) }

    @original_stderr.write(message)
  end

  def method_missing(method, *, &)
    @original_stderr.send(method, *, &)
  end

  def respond_to_missing?(method, include_private = false)
    @original_stderr.respond_to?(method, include_private)
  end
end

$stderr = WarningFilter.new(original_stderr)

ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../Gemfile', __dir__)

require 'bundler/setup' # Set up gems listed in the Gemfile.
require 'bootsnap/setup' # Speed up boot time by caching expensive operations.

# --- BEGIN: Global Psych/YAML patch for BigDecimal and Danconia::Money ---
begin
  require 'psych'
  require 'yaml'
  require 'bigdecimal'

  # Define permitted classes globally
  PSYCH_PERMITTED_CLASSES = [BigDecimal, Symbol].freeze

  # Simple, clean patches that don't create loops
  module PsychPatches
    def load(*, **kwargs)
      permitted_classes = Array(kwargs[:permitted_classes]) | PSYCH_PERMITTED_CLASSES
      permitted_classes << DANCONIA_MONEY if defined?(DANCONIA_MONEY)
      kwargs[:permitted_classes] = permitted_classes
      super
    end

    def safe_load(yaml, permitted_classes: [], **)
      permitted_classes = Array(permitted_classes) | PSYCH_PERMITTED_CLASSES
      permitted_classes << DANCONIA_MONEY if defined?(DANCONIA_MONEY)
      super
    end

    def dump(obj, *, **kwargs)
      permitted_classes = Array(kwargs[:permitted_classes]) | PSYCH_PERMITTED_CLASSES
      permitted_classes << DANCONIA_MONEY if defined?(DANCONIA_MONEY)
      kwargs[:permitted_classes] = permitted_classes
      super
    end
  end

  # Apply patches
  Psych.singleton_class.prepend(PsychPatches)
rescue LoadError
  # ignore
end
# --- END: Global Psych/YAML patch ---

# --- BEGIN: Set global default permitted classes for Psych/YAML ---
if defined?(Psych::DEFAULT_PERMITTED_CLASSES)
  permitted = [BigDecimal]
  permitted << DANCONIA_MONEY if defined?(DANCONIA_MONEY) && DANCONIA_MONEY
  Psych::DEFAULT_PERMITTED_CLASSES.replace((Psych::DEFAULT_PERMITTED_CLASSES + permitted).uniq)
end
if defined?(YAML::DEFAULT_PERMITTED_CLASSES)
  permitted = [BigDecimal]
  permitted << DANCONIA_MONEY if defined?(DANCONIA_MONEY) && DANCONIA_MONEY
  YAML::DEFAULT_PERMITTED_CLASSES.replace((YAML::DEFAULT_PERMITTED_CLASSES + permitted).uniq)
end
# --- END: Set global default permitted classes for Psych/YAML ---
