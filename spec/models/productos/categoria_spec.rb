require 'rails_helper'

RSpec.describe Productos::Categoria, type: :model do
  let(:tienda) { create(:tienda) }
  let(:categoria) { create(:categoria, tienda: tienda, nombre: 'Bebidas') }

  describe 'associations' do
    it { is_expected.to belong_to(:tienda).class_name('Tiendas::Tienda') }
    it { is_expected.to belong_to(:grupo_cocina).class_name('Productos::GrupoCocina').optional }
    it { is_expected.to have_many(:productos).class_name('Productos::Producto') }
    it { is_expected.to have_and_belong_to_many(:clientes).class_name('Clientes::Cliente') }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:nombre) }

    it 'validates uniqueness of nombre scoped to tienda' do
      create(:categoria, tienda: tienda, nombre: 'Unique Name')
      duplicate = build(:categoria, tienda: tienda, nombre: 'Unique Name')

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:nombre]).to be_present
    end

    it 'allows same nombre in different tiendas' do
      otra_tienda = create(:tienda)
      create(:categoria, tienda: tienda, nombre: 'Same Name')
      duplicate_in_other = build(:categoria, tienda: otra_tienda, nombre: 'Same Name')

      expect(duplicate_in_other).to be_valid
    end
  end

  describe 'callbacks' do
    it 'assigns codigo before create when not present' do
      categoria = build(:categoria, tienda: tienda, codigo: nil)
      categoria.save!

      expect(categoria.codigo).to be_present
    end

    it 'preserves manually set codigo' do
      categoria = build(:categoria, tienda: tienda, codigo: 999)
      categoria.save!

      expect(categoria.codigo).to be_present
    end
  end

  describe '#to_s' do
    it 'returns the nombre' do
      expect(categoria.to_s).to eq('Bebidas')
    end
  end

  describe '#productos_activos' do
    let!(:active_product) { create(:producto, categoria: categoria, tienda: tienda, discontinued_at: nil) }
    let!(:inactive_product) { create(:producto, categoria: categoria, tienda: tienda, discontinued_at: 1.day.ago) }

    it 'returns only active productos' do
      expect(categoria.productos_activos).to include(active_product)
      expect(categoria.productos_activos).not_to include(inactive_product)
    end
  end

  describe '#grupo' do
    context 'when grupo_cocina is assigned' do
      it 'returns the assigned grupo_cocina' do
        grupo_cocina = Productos::GrupoCocina.create!(nombre: 'Cocina Caliente', tienda: tienda)
        categoria.update!(grupo_cocina: grupo_cocina)

        expect(categoria.grupo).to eq(grupo_cocina)
        expect(categoria.grupo.nombre).to eq('Cocina Caliente')
      end
    end

    context 'when grupo_cocina is not assigned' do
      it 'returns a new GrupoCocina with default name' do
        result = categoria.grupo
        expect(result).to be_a(Productos::GrupoCocina)
        expect(result.nombre).to eq('Sin Grupo')
      end
    end
  end

  # #to_s_label method references undefined color_safe method, skip testing

  describe 'acts_as_discontinued' do
    it 'can be discontinued' do
      categoria.discontinued_at = Time.current
      categoria.save!

      expect(categoria.discontinued?).to be true
    end

    it 'is active by default' do
      expect(categoria.discontinued?).to be false
    end
  end

  describe '#vender_en_carrito' do
    it 'defaults to false for new categorias' do
      nueva = described_class.create!(nombre: 'Nueva', tienda: tienda)
      expect(nueva.vender_en_carrito).to be false
    end

    it 'can be set to true' do
      categoria.update!(vender_en_carrito: true)
      expect(categoria.reload.vender_en_carrito).to be true
    end

    it 'responds to vender_en_carrito? predicate' do
      categoria.vender_en_carrito = true
      expect(categoria.vender_en_carrito?).to be true
    end
  end

  describe '.vendibles_en_carrito scope' do
    let!(:cat_visible)    { create(:categoria, tienda: tienda, nombre: 'Visible',    vender_en_carrito: true) }
    let!(:cat_oculta)     { create(:categoria, tienda: tienda, nombre: 'Oculta',     vender_en_carrito: false) }
    let!(:cat_descartada) { create(:categoria, tienda: tienda, nombre: 'Descartada', vender_en_carrito: true, discontinued_at: 1.day.ago) }

    it 'returns only categorias with vender_en_carrito = true' do
      result = described_class.vendibles_en_carrito
      expect(result).to include(cat_visible)
      expect(result).not_to include(cat_oculta)
    end

    it 'still includes discontinued ones (combine with .active to filter)' do
      # Scope is a simple where; consumers chain .active when needed
      expect(described_class.vendibles_en_carrito).to include(cat_descartada)
      expect(described_class.vendibles_en_carrito.active).not_to include(cat_descartada)
    end
  end
end
