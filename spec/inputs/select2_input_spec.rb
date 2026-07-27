require 'rails_helper'

RSpec.describe Select2Input do
  let(:object) { double('Object', name: 'Test Name', name_id: 123) }
  let(:object_class) { double('Class', human_attribute_name: 'Nombre') }
  let(:template) { double('Template') }

  let(:form_builder) do
    double('FormBuilder',
           object: object,
           object_name: 'test_object',
           template: template)
  end

  before do
    allow(object).to receive_messages(class: object_class, to_json: '{"id":123,"name":"Test"}')
  end

  describe '#initialize' do
    it 'sets label from human_attribute_name' do
      input = described_class.new(
        form_builder,
        :name,
        nil,
        :string,
        { input_html: { data: {} } }
      )

      expect(input.options[:label]).to eq 'Nombre'
    end

    it 'adds select2-remote class' do
      input = described_class.new(
        form_builder,
        :name,
        nil,
        :string,
        { input_html: { class: '', data: {} } }
      )

      expect(input.input_html_options[:class]).to include('select2-remote')
    end

    it 'appends _id to attribute name if not present' do
      input = described_class.new(
        form_builder,
        :name,
        nil,
        :string,
        { input_html: { data: {} } }
      )

      expect(input.attribute_name).to eq 'name_id'
    end

    it 'does not modify attribute name if it ends with _id' do
      allow(object).to receive(:category_id).and_return(1)

      input = described_class.new(
        form_builder,
        :category_id,
        nil,
        :string,
        { input_html: { data: {} } }
      )

      expect(input.attribute_name).to eq :category_id
    end

    it 'does not modify attribute name if it ends with _ids' do
      allow(object).to receive(:category_ids).and_return([1, 2])

      input = described_class.new(
        form_builder,
        :category_ids,
        nil,
        :string,
        { input_html: { data: {} } }
      )

      expect(input.attribute_name).to eq :category_ids
    end

    it 'does not modify attribute name if it ends with _eq' do
      allow(object).to receive(:name_eq).and_return('test')

      input = described_class.new(
        form_builder,
        :name_eq,
        nil,
        :string,
        { input_html: { data: {} } }
      )

      expect(input.attribute_name).to eq :name_eq
    end

    it 'does not modify attribute name if it ends with _any' do
      allow(object).to receive(:tags_any).and_return(['tag1', 'tag2'])

      input = described_class.new(
        form_builder,
        :tags_any,
        nil,
        :string,
        { input_html: { data: {} } }
      )

      expect(input.attribute_name).to eq :tags_any
    end

    it 'sets pre data from object attribute' do
      allow(object).to receive_messages(name: 'Test Value', to_json: '"Test Value"')

      input = described_class.new(
        form_builder,
        :name,
        nil,
        :string,
        { input_html: { data: {} } }
      )

      expect(input.input_html_options[:data][:pre]).to be_present
    end
  end
end
