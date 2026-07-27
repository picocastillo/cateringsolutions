class ApplicationJob < ActiveJob::Base
  rescue_from Exception do |error|
    Notify.exception error
    raise error
  end

  retry_on SocketError, attempts: 4, wait: :exponentially_longer do |_job, error|
    Notify.exception error
  end
end
