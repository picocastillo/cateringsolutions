require 'rails_helper'

RSpec.describe FormattingHelper, type: :helper do
  describe '#percent' do
    it 'formats value as percentage with default decimals' do
      expect(helper.percent(25)).to eq '25,0%'
    end

    it 'formats value with custom decimals' do
      expect(helper.percent(25.555, 2)).to eq '25,56%'
    end

    it 'returns nil for blank value' do
      expect(helper.percent(nil)).to be_nil
      expect(helper.percent('')).to be_nil
    end
  end

  describe '#percent_int' do
    it 'formats value as integer percentage' do
      expect(helper.percent_int(25.7)).to eq '26%'
    end
  end

  describe '#format_money' do
    it 'formats regular number as currency' do
      result = helper.format_money(1234.56)
      expect(result).to include('1.234,56')
    end

    it 'formats with custom decimals' do
      result = helper.format_money(1234.567, decimals: 3)
      expect(result).to include('1.234,567')
    end
  end

  describe '#decimal' do
    it 'formats number with default 2 decimals' do
      expect(helper.decimal(123.456)).to eq '123.46'
    end

    it 'formats number with custom decimals' do
      expect(helper.decimal(123.456, 3)).to eq '123.456'
    end

    it 'returns nil for nil input' do
      expect(helper.decimal(nil)).to be_nil
    end
  end

  describe '#graduacion' do
    it 'formats positive number with sign' do
      expect(helper.graduacion(5.5)).to eq '+5.50'
    end

    it 'formats negative number with sign' do
      expect(helper.graduacion(-3.2)).to eq '-3.20'
    end

    it 'returns nil for nil input' do
      expect(helper.graduacion(nil)).to be_nil
    end
  end

  describe '#angulo' do
    it 'formats number with degree symbol' do
      expect(helper.angulo(45)).to eq '45°'
    end

    it 'returns nil for nil input' do
      expect(helper.angulo(nil)).to be_nil
    end
  end

  describe '#sino' do
    it 'returns Si for true' do
      expect(helper.sino(true)).to eq 'Si'
    end

    it 'returns No for false' do
      expect(helper.sino(false)).to eq 'No'
    end
  end

  describe '#active_label' do
    it 'renders Activado label for active object' do
      object = double('Object', active?: true)
      result = helper.active_label(object)

      expect(result).to include('Activado')
      expect(result).to include('label')
      expect(result).to include('activado')
    end

    it 'renders Desactivado label for inactive object' do
      object = double('Object', active?: false)
      result = helper.active_label(object)

      expect(result).to include('Desactivado')
      expect(result).to include('label')
      expect(result).to include('desactivado')
    end
  end

  describe '#estado_label' do
    let(:estado) { double('Estado', to_s: 'Pendiente', to_sym: :pendiente, tip: 'Esperando confirmación', try: ->(method) { method == :tip ? 'Esperando confirmación' : nil }) }
    let(:objeto) { double('Objeto', estado: estado) }

    it 'renders full estado label' do
      result = helper.estado_label(objeto)

      expect(result).to include('Pendiente')
      expect(result).to include('label')
      expect(result).to include('pendiente')
    end

    it 'renders abbreviated estado label' do
      result = helper.estado_label(objeto, true)

      expect(result).to include('P')
      expect(result).to include('label')
    end

    it 'includes tooltip data' do
      result = helper.estado_label(objeto)
      expect(result).to include('data-tooltip')
    end
  end
end
