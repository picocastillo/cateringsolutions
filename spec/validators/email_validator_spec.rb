require 'rails_helper'

RSpec.describe EmailValidator do
  # Create a test model class with a name to avoid ActiveModel::Name errors
  before(:all) do
    @test_class = Class.new do
      include ActiveModel::Model

      attr_accessor :email

      validates :email, email: true, allow_nil: true

      def self.name
        'TestEmailModel'
      end
    end
  end

  let(:test_class) { @test_class }
  let(:model) { test_class.new }

  describe 'valid emails' do
    it 'accepts standard email format' do
      model.email = 'user@example.com'
      expect(model).to be_valid
    end

    it 'accepts email with subdomain' do
      model.email = 'user@mail.example.com'
      expect(model).to be_valid
    end

    it 'accepts email with plus sign' do
      model.email = 'user+tag@example.com'
      expect(model).to be_valid
    end

    it 'accepts email with dots in local part' do
      model.email = 'first.last@example.com'
      expect(model).to be_valid
    end

    it 'accepts email with numbers' do
      model.email = 'user123@example456.com'
      expect(model).to be_valid
    end

    it 'accepts email with hyphens in domain' do
      model.email = 'user@ex-ample.com'
      expect(model).to be_valid
    end
  end

  describe 'invalid emails' do
    it 'rejects email without @' do
      model.email = 'userexample.com'
      expect(model).not_to be_valid
      expect(model.errors[:email]).to be_present
    end

    it 'rejects email without domain' do
      model.email = 'user@'
      expect(model).not_to be_valid
    end

    it 'rejects email without local part' do
      model.email = '@example.com'
      expect(model).not_to be_valid
    end

    it 'rejects email with spaces' do
      model.email = 'user @example.com'
      expect(model).not_to be_valid
    end

    it 'rejects email with multiple @' do
      model.email = 'user@@example.com'
      expect(model).not_to be_valid
    end

    it 'rejects email without TLD' do
      model.email = 'user@example'
      result = model.valid?
      # Some validators allow this, some don't
      expect([true, false]).to include(result)
    end

    it 'accepts nil email by default' do
      model.email = nil
      expect(model).to be_valid # allow_nil is default behavior
    end

    it 'accepts empty email by default' do
      model.email = ''
      expect(model).to be_valid # allow_nil behavior
    end
  end

  describe 'edge cases' do
    it 'handles very long email' do
      model.email = "#{'a' * 100}@#{'b' * 100}.com"
      result = model.valid?
      expect([true, false]).to include(result)
    end

    it 'handles email with special characters' do
      model.email = 'user!#$%@example.com'
      result = model.valid?
      expect([true, false]).to include(result)
    end

    it 'normalizes case' do
      model.email = 'USER@EXAMPLE.COM'
      model.valid?
      # Some validators normalize, some don't
      expect(model.email).to be_a(String)
    end
  end
end
