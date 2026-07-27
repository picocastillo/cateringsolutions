class SeedDescuentosVentaMostradorTienda3 < ActiveRecord::Migration[7.1]
  def up
    tienda = Tiendas::Tienda.find_by(id: 3)
    return unless tienda

    # Find or create cliente "Empleados Cotidiano"
    cliente_empleados = Clientes::Cliente.find_or_create_by!(
      nombre: 'Empleados Cotidiano',
      tienda: tienda
    ) do |c|
      c.dia_inicio_ciclo_facturacion = 1
      c.vencimiento_a = 30
      c.cuit = '20000000001'
      c.horario_corte_pedidos = '12:00'
    end

    # Descuento 1: 10% en efectivo para todos los clientes, mínimo $30.000
    VentasMostrador::DescuentoVentaMostrador.find_or_create_by!(
      tienda: tienda,
      nombre: '10% descuento'
    ) do |d|
      d.tipo_descuento = 'porcentaje'
      d.porcentaje = 10
      d.medio_pago_tipo = 'efectivo'
      d.importe_minimo = 30_000
      d.limite_bonificacion = 1_000_000
      d.activo = true
    end

    # Descuento 2: 20% para empleados, cualquier medio de pago
    descuento_empleados = VentasMostrador::DescuentoVentaMostrador.find_or_create_by!(
      tienda: tienda,
      nombre: '20% descuento empleados'
    ) do |d|
      d.tipo_descuento = 'porcentaje'
      d.porcentaje = 20
      d.medio_pago_tipo = ''
      d.importe_minimo = 0
      d.limite_bonificacion = 1_000_000
      d.activo = true
    end
    descuento_empleados.clientes << cliente_empleados unless descuento_empleados.clientes.exists?(id: cliente_empleados.id)
  end

  def down
    tienda = Tiendas::Tienda.find_by(id: 3)
    return unless tienda

    VentasMostrador::DescuentoVentaMostrador
      .where(tienda: tienda, nombre: ['10% descuento', '20% descuento empleados'])
      .destroy_all

    Clientes::Cliente.where(tienda: tienda, nombre: 'Empleados Cotidiano').destroy_all
  end
end
