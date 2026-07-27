require 'danconia/exchanges/currency_layer'
require 'danconia/stores/active_record'

exchange = if Rails.env.production? || Rails.env.staging?
             Danconia::Exchanges::CurrencyLayer.new access_key: '6e171d208dc088b416bb41fb71e76198', store: Danconia::Stores::ActiveRecord.new
           else
             Danconia::Exchanges::FixedRates.new rates: { 'USDARS' => 41.60243, 'USDEUR' => 0.85804 }
           end

Danconia.configure do |config|
  config.default_currency = 'ARS'
  config.default_exchange = exchange
  config.available_currencies = [
    { code: 'ARS', symbol: '$' },
    { code: 'USD', symbol: 'US$' },
    { code: 'EUR', symbol: '€' }
  ]
end
