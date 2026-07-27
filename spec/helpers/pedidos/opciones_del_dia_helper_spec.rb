require 'rails_helper'

RSpec.describe Pedidos::OpcionesDelDiaHelper, type: :helper do
  let(:tienda) { Tiendas::Tienda.create!(nombre: 'Tienda OD') }
  let(:categoria) { Productos::Categoria.create!(nombre: 'Cat OD', tienda: tienda) }
  let(:categoria_md) { Productos::Categoria.create!(nombre: 'Cat MD', tienda: tienda, menu_diario: true) }
  let(:producto) { Productos::Producto.create!(nombre: 'Producto OD', tienda: tienda, categoria: categoria) }
  let(:producto_md) { Productos::Producto.create!(nombre: 'Producto MD', tienda: tienda, categoria: categoria_md) }
  let(:cliente) do
    Clientes::Cliente.create!(nombre: 'Cliente OD', cuit: '20294834487',
                              dia_inicio_ciclo_facturacion: 1, vencimiento_a: 1,
                              horario_corte_pedidos: '12:00', tienda: tienda)
  end
  let(:cuenta) { Clientes::Cuenta.create!(nombre: 'Cuenta OD', cliente: cliente) }
  let(:autor) do
    Usuarios::Usuario.create!(nombre: 'Autor OD', login: 'autor_od',
                              password: 'password123', password_confirmation: 'password123',
                              email: 'autor_od@example.com', tipo_usuario_id: 1,
                              dni: 12_345_690, cuenta: cuenta)
  end
  let(:fecha) { Time.zone.today }
  let(:pedido) { instance_double(Pedidos::Pedido, fecha: fecha) }

  before do
    Productos::Precio.create!(producto: producto, importe: 99, fecha_desde: fecha - 1)
  end

  def crear_md(tipo_id:, prod: producto, desc: 'Op del dia')
    MenusDiarios::MenuDiario.create!(productos: [prod], fecha: fecha, descripcion: desc,
                                     tienda: tienda, autor: autor, tipo_id: tipo_id)
  end

  describe '#productos_diarios_para' do
    context 'when tienda does not support productos_diarios' do
      it 'returns []' do
        tienda.update!(soporta_productos_diarios: false)
        crear_md(tipo_id: MenusDiarios::Tipo[:productos_diarios].id)
        expect(helper.productos_diarios_para(pedido, cuenta, tienda)).to eq []
      end
    end

    context 'when tienda supports productos_diarios' do
      before { tienda.update!(soporta_productos_diarios: true) }

      it 'returns [] when there are no productos_diarios menus' do
        crear_md(tipo_id: MenusDiarios::Tipo[:menu_diario].id, prod: producto_md, desc: 'Solo MD')
        expect(helper.productos_diarios_para(pedido, cuenta, tienda)).to eq []
      end

      it 'returns [] when cuenta_activa is nil' do
        crear_md(tipo_id: MenusDiarios::Tipo[:productos_diarios].id)
        expect(helper.productos_diarios_para(pedido, nil, tienda)).to eq []
      end

      it 'returns [menu, precios] for each productos_diarios menu' do
        md = crear_md(tipo_id: MenusDiarios::Tipo[:productos_diarios].id)
        result = helper.productos_diarios_para(pedido, cuenta, tienda)
        expect(result.length).to eq 1
        menu, precios = result.first
        expect(menu).to eq md
        expect(precios.map(&:producto)).to eq [producto]
      end

      it 'excludes menus whose productos have no resolvable precio' do
        otro = Productos::Producto.create!(nombre: 'Sin precio', tienda: tienda, categoria: categoria)
        crear_md(tipo_id: MenusDiarios::Tipo[:productos_diarios].id, prod: otro, desc: 'Sin precio')
        expect(helper.productos_diarios_para(pedido, cuenta, tienda)).to eq []
      end
    end
  end
end
