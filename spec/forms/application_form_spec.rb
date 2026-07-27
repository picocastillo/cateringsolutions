require 'rails_helper'

RSpec.describe ApplicationForm do
  describe '#persisted?' do
    it 'returns false' do
      expect(described_class.new.persisted?).to be false
    end
  end

  describe '.belongs_to' do
    let(:form_class) do
      Class.new(described_class) do
        belongs_to :tienda, Tiendas::Tienda
      end
    end

    it 'defines _id accessor' do
      form = form_class.new
      form.tienda_id = 42
      expect(form.tienda_id).to eq 42
    end

    it 'defines reader that finds by id' do
      tienda = create(:tienda)
      form = form_class.new
      form.tienda_id = tienda.id
      expect(form.tienda).to eq tienda
    end

    it 'defines writer that sets id from record' do
      tienda = create(:tienda)
      form = form_class.new
      form.tienda = tienda
      expect(form.tienda_id).to eq tienda.id
    end

    it 'returns nil when id is nil' do
      form = form_class.new
      form.tienda_id = nil
      expect(form.tienda).to be_nil
    end

    it 'caches the record after first access' do
      tienda = create(:tienda)
      form = form_class.new
      form.tienda_id = tienda.id
      form.tienda # first call
      expect(Tiendas::Tienda).not_to receive(:find_by_id)
      form.tienda # second call uses cache
    end
  end

  describe '.has_many' do
    let(:form_class) do
      Class.new(described_class) do
        has_many :categorias, Productos::Categoria
      end
    end

    it 'defines _ids accessor' do
      form = form_class.new
      form.categorias_ids = [1, 2, 3]
      expect(form.categorias_ids).to eq [1, 2, 3]
    end

    it 'handles string ids (comma-separated)' do
      tienda = create(:tienda)
      cat1 = create(:categoria, tienda: tienda)
      cat2 = create(:categoria, tienda: tienda)

      form = form_class.new
      form.categorias_ids = "#{cat1.id},#{cat2.id}"
      expect(form.categorias).to include(cat1, cat2)
    end

    it 'handles array ids' do
      tienda = create(:tienda)
      cat1 = create(:categoria, tienda: tienda)

      form = form_class.new
      form.categorias_ids = [cat1.id]
      expect(form.categorias).to include(cat1)
    end

    it 'defines writer that sets ids from records' do
      tienda = create(:tienda)
      cat1 = create(:categoria, tienda: tienda)
      cat2 = create(:categoria, tienda: tienda)

      form = form_class.new
      form.categorias = [cat1, cat2]
      expect(form.categorias_ids).to eq [cat1.id, cat2.id]
    end
  end

  describe 'Virtus model integration' do
    it 'includes ActiveModel::Validations' do
      expect(described_class.ancestors).to include(ActiveModel::Validations)
    end

    it 'includes ActiveModel::Conversion' do
      expect(described_class.ancestors).to include(ActiveModel::Conversion)
    end
  end
end
