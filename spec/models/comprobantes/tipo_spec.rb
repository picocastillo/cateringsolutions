require 'rails_helper'

RSpec.describe Comprobantes::Tipo, type: :model do
  describe 'class methods' do
    describe '.[]' do
      it 'finds tipo by description' do
        tipo = described_class.create!(codigo: 1, desc: 'Factura A', clase: 'Ventas::Facturacion::Factura', letra: 'A')
        expect(described_class['Factura A']).to eq tipo
      end

      it 'returns nil for non-existent description' do
        expect(described_class['NoExiste']).to be_nil
      end
    end

    describe '.categorias' do
      it 'returns hash of categorias' do
        # Create some tipos
        described_class.create!(codigo: 1, desc: 'Factura A', clase: 'Ventas::Facturacion::Factura', letra: 'A')

        result = described_class.categorias
        expect(result).to be_a(Hash)
      end
    end
  end

  describe 'instance methods' do
    let(:tipo) { described_class.new(codigo: 1, desc: 'Factura A', clase: 'Ventas::Facturacion::Factura', letra: 'A') }

    describe '#codigo_to_s' do
      it 'formats codigo with leading zero' do
        expect(tipo.codigo_to_s).to eq '01'
      end

      it 'formats two-digit codigo' do
        tipo.codigo = 15
        expect(tipo.codigo_to_s).to eq '15'
      end
    end

    describe '#abrev' do
      it 'returns abbreviation from class capitals plus letra' do
        expect(tipo.abrev).to eq 'VFFA'
      end

      it 'works with NotaCredito' do
        tipo.clase = 'Ventas::Facturacion::NotaCredito'
        tipo.letra = 'B'
        expect(tipo.abrev).to eq 'VFNCB'
      end
    end

    describe '#inicial' do
      it 'returns last capital letter from clase' do
        expect(tipo.inicial).to eq 'F'
      end

      it 'works with NotaCredito' do
        tipo.clase = 'Ventas::Facturacion::NotaCredito'
        expect(tipo.inicial).to eq 'C'
      end
    end

    describe '#name' do
      it 'returns underscored clase' do
        expect(tipo.name).to eq 'ventas/facturacion/factura'
      end
    end

    describe '#to_s' do
      it 'returns description' do
        expect(tipo.to_s).to eq 'Factura A'
      end
    end

    describe '#categoria' do
      it 'removes single capital letters from description' do
        expect(tipo.categoria).to eq 'Factura'
      end

      it 'strips whitespace' do
        tipo.desc = 'Nota de Crédito B'
        expect(tipo.categoria).to eq 'Nota de Crédito'
      end
    end

    describe '#formato_corto' do
      it 'returns RTO + letra for Factura' do
        expect(tipo.formato_corto).to eq 'RTOA'
      end

      it 'returns ND + letra for NotaDebito' do
        tipo.clase = 'Ventas::Facturacion::NotaDebito'
        tipo.letra = 'B'
        expect(tipo.formato_corto).to eq 'NDB'
      end

      it 'returns NC + letra for NotaCredito' do
        tipo.clase = 'Ventas::Facturacion::NotaCredito'
        tipo.letra = 'C'
        expect(tipo.formato_corto).to eq 'NCC'
      end

      it 'returns OP for OrdenPago' do
        tipo.clase = 'Ventas::Facturacion::OrdenPago'
        expect(tipo.formato_corto).to eq 'OP'
      end
    end

    describe '#signear' do
      it 'returns positive monto when debitan is true' do
        allow(tipo).to receive(:debitan?).and_return(true)
        expect(tipo.signear(100)).to eq 100
      end

      it 'returns negative monto when debitan is false' do
        allow(tipo).to receive(:debitan?).and_return(false)
        expect(tipo.signear(100)).to eq(-100)
      end

      it 'returns nil when monto is nil' do
        expect(tipo.signear(nil)).to be_nil
      end
    end
  end
end
