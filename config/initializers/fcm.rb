if Rails.env.test?
  # Mock FCM for test environment
  class MockFCM
    def initialize(*); end

    def send(*)
      { status_code: 200, body: 'mocked' }
    end
  end
  $fcm = MockFCM.new
else
  $fcm = FCM.new AppConfig.firebase.server_key
end
