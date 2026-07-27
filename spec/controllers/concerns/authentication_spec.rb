require 'rails_helper'

RSpec.describe Authentication do
  describe 'module inclusion' do
    it 'can be included in controllers' do
      controller_class = Class.new do
        def self.helper_method(*args); end
        include Authentication
      end
      expect(controller_class.included_modules).to include(described_class)
    end

    it 'defines protected methods' do
      controller_class = Class.new do
        def self.helper_method(*args); end
        include Authentication
      end
      instance = controller_class.new
      expect(instance.protected_methods).to include(:logged_in?)
      expect(instance.protected_methods).to include(:current_authenticated_user)
      expect(instance.protected_methods).to include(:authorized?)
    end
  end
end
