# Stub dollar exchange rate API HTTP calls for test environment.
# Prevents any real HTTP requests to dolarapi.com / argentinadatos.com.
# Individual specs that need specific responses override Net::HTTP stubs.
if Rails.env.test?
  Rails.application.config.after_initialize do
    # Block real HTTP calls from the dolar service in tests.
    # The service specs stub Net::HTTP themselves to test specific scenarios.
    # The model specs stub DolarApiService with instance_double.
    # ActiveJob queue_adapter :test prevents jobs from actually running.
    # This is a safety net for any accidental direct calls.
  end
end
