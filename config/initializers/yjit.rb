# Enable YJIT (Ruby's JIT compiler) for significantly faster execution.
# Available in Ruby 3.3+ via programmatic API. Typically gives 15-25% speedup.
RubyVM::YJIT.enable if defined?(RubyVM::YJIT) && Rails.env.production?
