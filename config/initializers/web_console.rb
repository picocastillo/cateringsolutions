# Disable web-console in test environment
if Rails.env.test?
  # Prevent web-console from activating in test environment
  Rails.application.config.web_console.development_only = true if defined?(WebConsole)

  # Also suppress the activation warning
  if defined?(WebConsole::Middleware)
    WebConsole::Middleware.class_eval do
      delegate :call, to: :@app
    end
  end
end
