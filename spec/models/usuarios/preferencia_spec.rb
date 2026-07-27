require 'rails_helper'

RSpec.describe Usuarios::Preferencia, type: :model do
  it 'is valid with valid attributes' do
    expect(described_class.new).to be_a(described_class)
  end
end
