require 'rails_helper'

# Regression: `menu_diario_tipo_visuals` used to call
# `MenusDiarios::Tipo.find_by(id: …)`, but ArEnums::Base does NOT expose
# ActiveRecord-style finders — the call raised `NoMethodError`. Every caller
# (calendar JSON, pedidos panels, etc.) crashed for tiendas that had any
# MenuDiario, which surfaced as "the menu I just created isn't shown".
RSpec.describe MenusDiarios::TiposHelper, type: :helper do
  describe '#menu_diario_tipo_visuals' do
    it 'returns the productos_diarios visuals for a PD MenuDiario instance' do
      menu = MenusDiarios::MenuDiario.new(tipo_id: MenusDiarios::Tipo[:productos_diarios].id)
      v = helper.menu_diario_tipo_visuals(menu)
      expect(v[:emoji]).to eq('⭐')
      expect(v[:color]).to eq('#8b5cf6')
    end

    it 'returns the menu_diario visuals for an MD MenuDiario instance' do
      menu = MenusDiarios::MenuDiario.new(tipo_id: MenusDiarios::Tipo[:menu_diario].id)
      v = helper.menu_diario_tipo_visuals(menu)
      expect(v[:emoji]).to eq('🍽️')
      expect(v[:color]).to eq('#f59e0b')
    end

    it 'looks up by integer tipo_id without raising' do
      v = helper.menu_diario_tipo_visuals(MenusDiarios::Tipo[:productos_diarios].id)
      expect(v[:emoji]).to eq('⭐')
    end

    it 'looks up by symbol' do
      expect(helper.menu_diario_tipo_visuals(:menu_diario)[:emoji]).to eq('🍽️')
      expect(helper.menu_diario_tipo_visuals(:productos_diarios)[:emoji]).to eq('⭐')
    end

    it 'looks up by Tipo enum value' do
      expect(helper.menu_diario_tipo_visuals(MenusDiarios::Tipo[:menu_diario])[:emoji]).to eq('🍽️')
    end

    it 'falls back to default visuals for unknown tipo_id' do
      menu = MenusDiarios::MenuDiario.new(tipo_id: 9999)
      expect { helper.menu_diario_tipo_visuals(menu) }.not_to raise_error
      expect(helper.menu_diario_tipo_visuals(menu)).to eq(MenusDiarios::TiposHelper::DEFAULT_TIPO_VISUALS)
    end

    it 'falls back to default visuals for nil tipo_id' do
      menu = MenusDiarios::MenuDiario.new(tipo_id: nil)
      expect { helper.menu_diario_tipo_visuals(menu) }.not_to raise_error
    end
  end
end
