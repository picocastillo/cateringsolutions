module Usuarios
  class UsuariosExporter < ExcelExporter
    def headers
      [
        'DNI', 'Cuit', 'Legajo', 'Cliente', 'Cuenta', 'Nombre Usuario', 'Login', 'Email', 'Encargado de Empresa', 'Sucursal'
      ]
    end

    def row(c)
      [
        c.dni, c.cuit, c.legajo, c.cuenta.try(&:cliente), c.cuenta.try(&:nombre),
        c.nombre, c.login, c.email, (c.administrador_de_empresa ? 'Si' : 'No'), c.sucursal
      ]
    end

    def search_scope
      Usuarios::UsuariosQuery.new(query_params).reorder(nil).order('usuarios.cuenta_id asc, usuarios.nombre asc')
    end
  end
end
