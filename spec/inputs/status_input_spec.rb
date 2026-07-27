require 'rails_helper'

RSpec.describe StatusInput do
  let(:form_builder) do
    double('FormBuilder',
           object: double('Object', class: double(human_attribute_name: 'Estado')),
           object_name: 'test_object',
           template: double('Template'))
  end

  let(:input) do
    described_class.new(
      form_builder,
      :status,
      nil,
      :collection_select,
      {}
    )
  end

  describe '#options' do
    it 'returns options hash' do
      options = input.options
      expect(options).to be_a(Hash)
    end

    it 'sets label to Estado' do
      options = input.options
      expect(options[:label]).to eq 'Estado'
    end

    it 'disables prompt' do
      options = input.options
      expect(options[:prompt]).to be false
    end

    it 'provides collection with three status options' do
      options = input.options
      collection = options[:collection]

      expect(collection).to be_an(Array)
      expect(collection.size).to eq 3
      expect(collection).to include(['Todos', 'all'])
      expect(collection).to include(['Solo activos', 'active'])
      expect(collection).to include(['Solo inactivos', 'inactive'])
    end

    it 'preserves existing options' do
      custom_input = described_class.new(
        form_builder,
        :status,
        nil,
        :collection_select,
        { label: 'Custom Label' }
      )

      options = custom_input.options
      expect(options[:label]).to eq 'Custom Label'
    end
  end
end
