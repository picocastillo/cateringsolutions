require 'rails_helper'

RSpec.describe DateValidator do
  let(:model_class) do
    Class.new do
      include ActiveModel::Validations

      attr_accessor :start_date, :end_date

      validates :start_date, date: { before: :end_date }
      validates :end_date, date: { after: :start_date }

      def self.name
        'TestModel'
      end

      def read_attribute_for_validation(attribute)
        send(attribute)
      end
    end
  end

  let(:model) { model_class.new }

  describe 'before validation' do
    it 'validates date is before another date' do
      model.start_date = Date.new(2025, 1, 1)
      model.end_date = Date.new(2025, 1, 2)
      expect(model).to be_valid
    end

    it 'fails when date is not before' do
      model.start_date = Date.new(2025, 1, 2)
      model.end_date = Date.new(2025, 1, 1)
      expect(model).not_to be_valid
    end
  end

  describe 'after validation' do
    it 'validates date is after another date' do
      model.start_date = Date.new(2025, 1, 1)
      model.end_date = Date.new(2025, 1, 2)
      expect(model).to be_valid
    end

    it 'fails when date is not after' do
      model.start_date = Date.new(2025, 1, 2)
      model.end_date = Date.new(2025, 1, 1)
      expect(model).not_to be_valid
    end
  end

  describe 'with allow_nil' do
    let(:nullable_model_class) do
      Class.new do
        include ActiveModel::Validations

        attr_accessor :optional_date

        validates :optional_date, date: { before: Time.zone.today }, allow_nil: true

        def self.name
          'NullableModel'
        end

        def read_attribute_for_validation(attribute)
          send(attribute)
        end
      end
    end

    it 'allows nil when allow_nil is true' do
      model = nullable_model_class.new
      model.optional_date = nil
      expect(model).to be_valid
    end
  end

  describe 'invalid date handling' do
    let(:invalid_date_model_class) do
      Class.new do
        include ActiveModel::Validations

        attr_accessor :date_field

        validates :date_field, date: true

        def self.name
          'InvalidDateModel'
        end

        def read_attribute_for_validation(attribute)
          send(attribute)
        end
      end
    end

    it 'adds error for invalid date string' do
      model = invalid_date_model_class.new
      model.date_field = 'invalid-date'
      expect(model).not_to be_valid
    end
  end
end
