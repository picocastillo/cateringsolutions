require 'rails_helper'

RSpec.describe Comprobantes::Totalizable do
  describe '#importe_total' do
    it 'sums importe of all items' do
      item1 = double('item', importe: Danconia::Money.new(100))
      item2 = double('item', importe: Danconia::Money.new(250))
      collection = [item1, item2]
      collection.extend(described_class)
      allow(collection).to receive(:load_target).and_return(collection)
      expect(collection.importe_total.to_f).to eq(350)
    end

    it 'returns zero for empty collection' do
      collection = []
      collection.extend(described_class)
      allow(collection).to receive(:load_target).and_return(collection)
      expect(collection.importe_total.to_f).to eq(0)
    end
  end
end
