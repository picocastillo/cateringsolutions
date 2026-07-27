module Usuarios
  class ServicioDeImpresion < ArEnums::Base
    enumeration [
      { id: 1, name: 'whb', desc: 'WHB' },
      { id: 2, name: 'qztray', desc: 'QZ Tray' }
    ]
  end
end
