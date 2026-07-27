require 'rails_helper'

RSpec.describe SerializeIds do
  let(:dummy_class) do
    Class.new do
      extend SerializeIds

      attr_accessor :data

      def [](key)
        data[key] if data
      end

      def []=(key, value)
        @data ||= {}
        @data[key] = value
      end

      def self.name
        'DummyClass'
      end
    end
  end

  let(:item_class) do
    Struct.new(:id, :name, :index) do
      def self.where(_conditions)
        [new(1, 'Item 1', 0), new(2, 'Item 2', 1)]
      end
    end
  end

  before do
    stub_const('ItemClass', item_class)
    dummy_class.serialize_ids(:items, 'ItemClass')
  end

  describe '#serialize_ids' do
    let(:instance) { dummy_class.new }

    it 'generates setter method' do
      expect(instance).to respond_to(:items_ids=)
    end

    it 'generates getter method' do
      expect(instance).to respond_to(:items_ids)
    end

    it 'stores ids as comma-separated string' do
      instance.items_ids = [1, 2, 3]
      expect(instance[:items_ids]).to eq('1,2,3')
    end

    it 'retrieves ids as array' do
      instance[:items_ids] = '1,2,3'
      expect(instance.items_ids).to eq([1, 2, 3])
    end

    it 'filters blank values' do
      instance.items_ids = [1, '', 2, nil, 3]
      expect(instance[:items_ids]).to eq('1,2,3')
    end
  end
end
