require 'rails_helper'

RSpec.describe Cloning do
  let(:dummy_class) do
    Class.new do
      include Cloning
      include ActiveModel::Model

      attr_accessor :id, :name, :description, :created_at, :updated_at

      def attribute_names
        ['id', 'name', 'description', 'created_at', 'updated_at']
      end

      def self.reflections
        {}
      end
    end
  end

  let(:instance) do
    obj = dummy_class.new
    obj.id = 1
    obj.name = 'Original'
    obj.description = 'Original description'
    obj.created_at = Time.current
    obj.updated_at = Time.current
    obj
  end

  describe '#clonar' do
    it 'creates new instance' do
      clone = instance.clonar
      expect(clone).to be_a(dummy_class)
      expect(clone).not_to eq(instance)
    end

    it 'copies attributes except NON_CONTENT_ATTRIBUTES' do
      clone = instance.clonar
      expect(clone.name).to eq('Original')
      expect(clone.description).to eq('Original description')
      expect(clone.id).to be_nil
      expect(clone.created_at).to be_nil
    end

    it 'excludes specified attributes' do
      clone = instance.clonar(except: [:name])
      expect(clone.name).to be_nil
      expect(clone.description).to eq('Original description')
    end
  end

  describe '#copy_fields_from' do
    it 'copies specified fields' do
      target = dummy_class.new
      target.copy_fields_from(instance, ['name', 'description'])
      expect(target.name).to eq('Original')
      expect(target.description).to eq('Original description')
      expect(target.id).to be_nil
    end
  end
end
