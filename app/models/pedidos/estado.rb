module Pedidos
  class Estado < ArEnums::Base
    enumeration [
      { id: 1, name: 'pendiente', desc: 'En Carrito', tip: 'Se debe confirmar el pedido del carrito de compras.' },
      { id: 2, name: 'aceptado', desc: 'Aceptado',
        tip: 'El pedido ha sido aceptado y puede ser editado hasta la hora de corte de toma de pedidos.' },
      { id: 3, name: 'confirmado', desc: 'Confirmado',
        tip: 'El pedido ha sido confirmado y ha generado el remito correspondiente.' },
      { id: 4, name: 'finalizado', desc: 'Finalizado', tip: 'El pedido ha sido despachado y se considera Finalizado.' },
      { id: 5, name: 'cancelado', desc: 'Cancelado',
        tip: 'El pedido ha sido cancelado luego de Confirmado y se anularó su Remito con una Notas de Credito.' }
    ]
  end
end
