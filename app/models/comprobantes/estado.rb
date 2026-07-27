module Comprobantes
  class Estado < ArEnums::Base
    enumeration [
      { id: 1, name: 'pendiente', desc: 'Pendiente', tip: 'Se debe confirmar el comprobante.' },
      { id: 2, name: 'confirmado', desc: 'Confirmado',
        tip: 'El comprobante ha sido impreso y confirmado definitivamente.' }
    ]
  end
end
