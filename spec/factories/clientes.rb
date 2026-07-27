# Helper class for CUIT generation
class CuitGenerator
  def self.generate_valid_cuit
    # Generate a valid CUIT that passes the checksum validation
    base_digits = Array.new(10) { rand(10) }
    coefficients = [5, 4, 3, 2, 7, 6, 5, 4, 3, 2]

    # Calculate the check digit
    sum = base_digits.zip(coefficients).map { |digit, coeff| digit * coeff }.sum
    check_digit = (11 - (sum % 11)) % 11

    # If check digit is 11, use 0; if 10, regenerate
    check_digit = 0 if check_digit == 11
    return generate_valid_cuit if check_digit == 10

    (base_digits + [check_digit]).join
  end
end

FactoryBot.define do
  factory :cliente, class: 'Clientes::Cliente' do
    nombre { Faker::Company.name }
    transient do
      tienda { association(:tienda) }
    end
    tiendas { [tienda] }
    dia_inicio_ciclo_facturacion { 1 }
    vencimiento_a { 30 }
    cuit { CuitGenerator.generate_valid_cuit }
    horario_corte_pedidos { '12:00' }

    trait :with_cuenta do
      after(:create) do |cliente|
        create(:cuenta, cliente: cliente)
      end
    end
  end
end
