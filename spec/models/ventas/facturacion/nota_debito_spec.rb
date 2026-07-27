require 'rails_helper'

RSpec.describe Ventas::Facturacion::NotaDebito, type: :model do
  describe 'inheritance' do
    it 'inherits from Comprobante' do
      expect(described_class.superclass).to eq(Ventas::Facturacion::Comprobante)
    end
  end

  describe 'instance methods' do
    let(:nota_debito) { described_class.new }

    describe '#nota_debito?' do
      it 'returns true' do
        expect(nota_debito.nota_debito?).to be true
      end
    end

    describe '#nota?' do
      it 'returns true' do
        expect(nota_debito.nota?).to be true
      end
    end

    describe '#factura?' do
      it 'returns false' do
        expect(nota_debito.factura?).to be false
      end
    end

    describe '#debita?' do
      it 'returns true (nota_debito debita)' do
        expect(nota_debito.debita?).to be true
      end
    end

    describe '#acredita?' do
      it 'returns false' do
        expect(nota_debito.acredita?).to be false
      end
    end

    describe '#rol_asociado' do
      it 'returns generar_notas_debito symbol' do
        expect(nota_debito.rol_asociado).to eq(:generar_notas_debito)
      end
    end
  end

  describe 'callbacks' do
    describe '#asignar_tipo' do
      it 'assigns tipo with codigo 2 for new records' do
        tipo = Comprobantes::Tipo.find_or_create_by!(codigo: 2) do |t|
          t.desc = 'Nota de Débito'
          t.clase = 'Ventas::Facturacion::NotaDebito'
          t.letra = 'A'
        end
        nd = described_class.new
        nd.send(:asignar_tipo)
        expect(nd.tipo).to eq(tipo)
      end

      it 'does not assign tipo for existing records' do
        nd = described_class.new
        allow(nd).to receive(:new_record?).and_return(false)
        nd.send(:asignar_tipo)
        expect(nd.tipo).to be_nil
      end
    end
  end
end
