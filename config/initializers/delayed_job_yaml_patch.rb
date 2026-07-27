# Patch DelayedJob YAML loading to always permit BigDecimal and Danconia::Money
require 'delayed_job'
require 'psych'
require 'yaml'
require 'bigdecimal'

if defined?(Delayed::Job) && Delayed::Job.respond_to?(:deserialize)
  module Delayed
    class Job
      class << self
        alias orig_deserialize deserialize
      end

      def self.deserialize(source)
        permitted = [BigDecimal]
        permitted << DANCONIA_MONEY if defined?(DANCONIA_MONEY)
        if source.is_a?(String)
          Psych.safe_load(source, permitted_classes: permitted, aliases: true)
        else
          orig_deserialize(source)
        end
      end
    end
  end
end
