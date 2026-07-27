FactoryBot.define do
  factory :usuario, aliases: [:user], class: 'Usuarios::Usuario' do
    sequence(:nombre) { |n| "#{Faker::Name.first_name}#{n}" }
    sequence(:email) { |n| "user#{n}_#{SecureRandom.hex(4)}@example.com" }
    sequence(:login) { |n| "user_#{n}_#{SecureRandom.hex(4)}" }
    crypted_password { 'encrypted_password_hash' } # Skip password validation
    salt { 'salt_value' }
    dni { rand(1_000_000..99_999_999) } # Valid DNI length (1-9 characters)
    tipo_usuario_id { 2 } # Default to admin (operador) — :cliente trait overrides to 1
    association :visualizando_tienda, factory: :tienda
    # Don't set cuenta to avoid tiene_cuenta? validations

    # Step 8: non-cliente users must be linked via the usuarios_tiendas HABTM
    # to satisfy puede_loguearse_en?. Auto-link visualizando_tienda for any
    # usuario that isn't a cliente (cliente users authenticate via
    # cliente.tiendas, not the join table).
    after(:create) do |usuario|
      if usuario.tipo_usuario_id != 1 && usuario.visualizando_tienda &&
         usuario.tiendas.exclude?(usuario.visualizando_tienda)
        usuario.tiendas << usuario.visualizando_tienda
      end
    end

    trait :inactive do
      discontinued_at { Time.current }
    end

    trait :with_cuenta do
      association :cuenta, factory: :cuenta
      association :tienda_cliente, factory: :tienda
    end

    trait :with_password do
      password { 'password123' }
      password_confirmation { 'password123' }
      crypted_password { nil } # This will trigger password validation
    end

    trait :admin do
      # Admin users have access to all functionality
      tipo_usuario_id { 2 } # Assuming admin type

      after(:create) do |usuario|
        # Assign the admin role
        admin_rol = Usuarios::Rol.find_or_create_by(nombre: 'admin')
        usuario.roles << admin_rol unless usuario.roles.include?(admin_rol)
        usuario.reload # Reload to ensure role assignment is picked up
      end
    end

    trait :cliente do
      # Cliente users - customers who can place orders
      tipo_usuario_id { 1 } # Cliente type
      association :cuenta, factory: :cuenta

      after(:build) do |usuario|
        usuario.tienda_cliente = usuario.cuenta.cliente.tienda if usuario.cuenta&.cliente&.tienda
      end
    end
  end
end
