module MenusDiarios
  class Tipo < ArEnums::Base
    enumeration [
      { id: 1, name: 'menu_diario',       desc: 'Menú del Día',
        tip: 'Se renderiza en el panel "Menús del Día" con el formato de tarjeta de menú escolar.' },
      { id: 2, name: 'productos_diarios', desc: 'Productos del Día',
        tip: 'Se renderiza en el panel "Nuestras opciones del día" como un listado de productos.' }
    ]

    def self.find_by_id(id)
      all.detect { |t| t.id == id }
    end
  end
end
