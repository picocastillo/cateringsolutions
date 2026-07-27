require 'exception_notification/rails'

if Rails.env.production?
  ExceptionNotification.configure do |config|
    config.add_notifier :email, {
      email_prefix: '[Exception] ',
      sender_address: ExceptionSender,
      sections: ['request', 'backtrace'],
      background_sections: ['backtrace'],
      exception_recipients: ExceptionRecipients
    }
    config.ignored_exceptions += [
      'ActionController::InvalidAuthenticityToken', # Occurs with tabbed browsing
      'ActionDispatch::Http::MimeNegotiation::InvalidType' # Scanner probes with malformed Accept headers
    ]
  end
end
