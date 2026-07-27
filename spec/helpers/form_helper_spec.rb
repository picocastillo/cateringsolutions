require 'rails_helper'

RSpec.describe FormHelper, type: :helper do
  describe '#link_if' do
    it 'returns link when condition is true' do
      result = helper.link_if(true, 'Click', '/path')
      expect(result).to include('Click')
    end

    it 'returns nil when condition is false' do
      result = helper.link_if(false, 'Click', '/path')
      expect(result).to be_nil
    end
  end

  describe '#link_unless' do
    it 'returns link when condition is false' do
      result = helper.link_unless(false, 'Click', '/path')
      expect(result).to include('Click')
    end

    it 'returns nil when condition is true' do
      result = helper.link_unless(true, 'Click', '/path')
      expect(result).to be_nil
    end
  end

  describe '#table' do
    it 'creates table from list' do
      list = ['A', 'B', 'C', 'D', 'E', 'F']
      result = helper.table(list, 3)
      expect(result).to include('<table')
      expect(result).to include('table-values')
    end

    it 'groups items correctly' do
      list = ['A', 'B', 'C']
      result = helper.table(list, 3)
      expect(result).to include('<tr')
      expect(result).to include('<td')
    end
  end

  describe '#clear_fields' do
    it 'creates clear button' do
      result = helper.clear_fields
      expect(result).to include('Limpiar')
      expect(result).to include('btn')
      expect(result).to include('clear-form')
    end
  end
end
