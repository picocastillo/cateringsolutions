require 'rails_helper'

RSpec.describe WithinValidator do
  let(:model_class) do
    Class.new do
      include ActiveModel::Validations

      attr_accessor :age

      validates :age, within: { in: 18..65 }

      def self.name
        'TestModel'
      end
    end
  end

  describe 'validation' do
    it 'accepts value within range' do
      model = model_class.new
      model.age = 30
      expect(model).to be_valid
    end

    it 'accepts minimum value' do
      model = model_class.new
      model.age = 18
      expect(model).to be_valid
    end

    it 'accepts maximum value' do
      model = model_class.new
      model.age = 65
      expect(model).to be_valid
    end

    it 'rejects value below minimum' do
      model = model_class.new
      model.age = 17
      expect(model).not_to be_valid
      expect(model.errors[:age]).to include('debe estar entre 18 y 65')
    end

    it 'rejects value above maximum' do
      model = model_class.new
      model.age = 66
      expect(model).not_to be_valid
      expect(model.errors[:age]).to include('debe estar entre 18 y 65')
    end
  end

  describe 'custom message' do
    it 'generates default message with range' do
      validator = described_class.new(attributes: [:test], in: 1..10)
      expect(validator.options[:message]).to eq 'debe estar entre 1 y 10'
    end

    it 'preserves custom message if provided' do
      validator = described_class.new(attributes: [:test], in: 1..10, message: 'custom message')
      expect(validator.options[:message]).to eq 'custom message'
    end
  end
end
