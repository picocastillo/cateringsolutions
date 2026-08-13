require 'rails_helper'

RSpec.describe ApplicationHelper, type: :helper do
  describe '#color_cocina' do
    it 'returns RED when there are pedidos listos para cocinar (esperando)' do
      expect(helper.color_cocina(5, 2, 1)).to eq('#dc3545')
    end

    it 'returns RED even when all other counters are zero' do
      expect(helper.color_cocina(0, 3, 0)).to eq('#dc3545')
    end

    it 'returns GREEN when all pedidos are cocinados' do
      expect(helper.color_cocina(4, 0, 4)).to eq('#28a745')
    end

    it 'returns YELLOW when there are pendientes but no esperando' do
      expect(helper.color_cocina(5, 0, 2)).to eq('#ffb22b')
    end

    it 'returns YELLOW when total > 0 and cocinados is 0' do
      expect(helper.color_cocina(3, 0, 0)).to eq('#ffb22b')
    end

    it 'returns nil when all counters are zero (default/no color)' do
      expect(helper.color_cocina(0, 0, 0)).to be_nil
    end

    it 'handles nil values gracefully' do
      expect(helper.color_cocina(nil, nil, nil)).to be_nil
    end
  end

  describe '#page_id' do
    it 'generates page id from controller and action' do
      allow(helper).to receive_messages(controller_name: 'productos', action_name: 'index')

      expect(helper.page_id).to eq('page-productos-index')
    end

    it 'uses form for new action' do
      allow(helper).to receive_messages(controller_name: 'productos', action_name: 'new')

      expect(helper.page_id).to eq('page-productos-form')
    end

    it 'uses form for create action' do
      allow(helper).to receive_messages(controller_name: 'productos', action_name: 'create')

      expect(helper.page_id).to eq('page-productos-form')
    end

    it 'uses form for edit action' do
      allow(helper).to receive_messages(controller_name: 'productos', action_name: 'edit')

      expect(helper.page_id).to eq('page-productos-form')
    end

    it 'uses form for update action' do
      allow(helper).to receive_messages(controller_name: 'productos', action_name: 'update')

      expect(helper.page_id).to eq('page-productos-form')
    end

    it 'replaces underscores with hyphens' do
      allow(helper).to receive_messages(controller_name: 'stock_movimientos', action_name: 'show_details')

      expect(helper.page_id).to eq('page-stock-movimientos-show-details')
    end
  end

  describe '#discontinuado' do
    let(:active_model) { double('Model', to_s: 'Active Item', discontinued?: false) }
    let(:discontinued_model) { double('Model', to_s: 'Discontinued Item', discontinued?: true) }

    it 'returns plain string for active model' do
      result = helper.discontinuado(active_model)
      expect(result).to eq('Active Item')
    end

    it 'returns span with discontinuado class for discontinued model' do
      result = helper.discontinuado(discontinued_model)
      expect(result).to have_selector('span.discontinuado', text: 'Discontinued Item')
    end

    it 'uses custom string when provided' do
      result = helper.discontinuado(active_model, 'Custom Text')
      expect(result).to eq('Custom Text')
    end

    it 'wraps custom string with span for discontinued' do
      result = helper.discontinuado(discontinued_model, 'Custom Text')
      expect(result).to have_selector('span.discontinuado', text: 'Custom Text')
    end
  end

  describe '#page_entries_info' do
    let(:collection) do
      double('Collection',
             offset: 10,
             length: 20,
             total_entries: 100)
    end

    it 'returns pagination information' do
      result = helper.page_entries_info(collection)
      expect(result).to include('Viendo <b>11&nbsp;-30</b> de <b>100</b> totales')
    end

    it 'calculates offset correctly for first page' do
      collection = double('Collection', offset: 0, length: 25, total_entries: 100)
      result = helper.page_entries_info(collection)
      expect(result).to include('Viendo <b>1&nbsp;-25</b>')
    end
  end

  describe '#loading_indicator' do
    it 'returns a div with loading indicator class' do
      result = helper.loading_indicator
      expect(result).to have_selector('div.busy.loading-indicator')
    end
  end

  describe '#turbolinks_cache_control_meta_tag' do
    it 'returns meta tag with cache control' do
      result = helper.turbolinks_cache_control_meta_tag
      expect(result).to have_selector('meta[name="turbolinks-cache-control"][content="cache"]', visible: false)
    end

    it 'uses custom cache control when set' do
      helper.instance_variable_set(:@turbolinks_cache_control, 'no-cache')
      result = helper.turbolinks_cache_control_meta_tag
      expect(result).to have_selector('meta[name="turbolinks-cache-control"][content="no-cache"]', visible: false)
    end
  end

  describe '#modo_prueba?' do
    around do |example|
      original = ENV.fetch('MODO_PRUEBA', nil)
      begin
        example.run
      ensure
        if original.nil?
          ENV.delete('MODO_PRUEBA')
        else
          ENV['MODO_PRUEBA'] = original
        end
      end
    end

    it 'is true when MODO_PRUEBA is true' do
      ENV['MODO_PRUEBA'] = 'true'
      expect(helper.modo_prueba?).to be true
    end

    it 'is false when MODO_PRUEBA is unset' do
      ENV.delete('MODO_PRUEBA')
      expect(helper.modo_prueba?).to be false
    end

    it 'is false when MODO_PRUEBA is any other value' do
      ENV['MODO_PRUEBA'] = '1'
      expect(helper.modo_prueba?).to be false
    end
  end
end
