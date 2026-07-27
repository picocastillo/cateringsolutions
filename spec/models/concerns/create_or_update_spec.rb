require 'rails_helper'

RSpec.describe CreateOrUpdate do
  let(:dummy_class) do
    Class.new do
      extend CreateOrUpdate

      def self.find_or_initialize_by(conditions)
        new.tap { |obj| obj.instance_variable_set(:@conditions, conditions) }
      end

      def update!(attributes)
        @attributes = attributes
        self
      end
    end
  end

  describe '.create_or_update_by' do
    it 'finds or initializes by field' do
      result = dummy_class.create_or_update_by(:name, name: 'Test', value: 123)
      expect(result).to be_a(dummy_class)
    end

    it 'raises error when condition fields missing' do
      expect do
        dummy_class.create_or_update_by(:name, value: 123)
      end.to raise_error(ArgumentError, /should contain the condition fields/)
    end

    it 'accepts array of fields' do
      result = dummy_class.create_or_update_by([:name, :code], name: 'Test', code: 'ABC', value: 123)
      expect(result).to be_a(dummy_class)
    end
  end

  describe '.create_or_update' do
    it 'uses id as condition field' do
      result = dummy_class.create_or_update(id: 1, name: 'Test')
      expect(result).to be_a(dummy_class)
    end
  end
end
