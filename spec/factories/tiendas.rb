FactoryBot.define do
  factory :tienda, class: 'Tiendas::Tienda' do
    sequence(:nombre) { |n| "#{Faker::Company.name} #{n}" }
    sequence(:dominio) { |n| "tienda#{n}.test" }
    active { true }
    multiple_locales { false }
    muestra_mas_productos { true }
    muestra_mas_productos_por_categoria { false }
    muestra_menus_del_dia { true }

    # Default colors from Tienda 1 (Catering Solutions)
    color_de_fondo { '#fbfbfb' }
    color_de_menu { '#c1c1c1' }
    color_barra_superior { '#f2f2f2' }
    color_fondo_logo { '#f2f2f2' }
    color_barra_filtros { '#5c9bd2' }
    color_titulo { '#1c1c1c' }

    trait :inactive do
      active { false }
    end
  end
end
