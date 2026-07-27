require 'rails_helper'

RSpec.describe Ventas::Facturacion::Authorization, type: :model do
  it 'inherits from Ability::Subrules' do
    expect(described_class.ancestors).to include(Ability::Subrules)
  end
end
