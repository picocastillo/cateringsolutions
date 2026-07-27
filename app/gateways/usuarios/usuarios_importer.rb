module Usuarios
  class UsuariosImporter < ExcelImporter
    def extra_broadcast_data
      { usuarios_count: @usuarios_count || 0 }
    end

    def before_process
      @usuarios_count = 0
    end

    def process_row(row)
      c = row['ID'].blank? ? Usuarios::Usuario.new : Usuarios::Usuario.find(row['ID'])
      if c.new_record?
        c.tipo_usuario_id = 1
        dni = nil
        if row['Cuit'].present?
          c.cuit = row['Cuit'].to_s.gsub('-', '')
          dni = row['Cuit'].to_s.gsub('-', '')[2..-2]
        end
        c.dni = (row['DNI'].presence || dni)
        raise ErrorAplicacion, 'No se permiten crear usuarios sin DNI.' if c.dni.blank?

        c.password_expires_at = 5.days.ago
      end
      c.email = row['Email'] if row['Email'].present?
      if row['Cliente'].present?
        cl = Clientes::Cliente.where(nombre: row['Cliente'].split.map do |x|
          x.strip.capitalize
        end.join(' ')).first or raise ErrorAplicacion,
                                      'No se permiten crear usuarios de un Cliente inexistente.'
        if row['Cuenta'].present?
          ca = cl.cuentas.find { |x| x.nombre == row['Cuenta'].split.map(&:strip).join(' ') }
          c.sucursal = row['Sucursal'] if row['Sucursal'].present?
          cuenta = ca
        else
          cuenta = cl.cuenta_principal
        end
      end
      c.cuenta = cuenta or raise ErrorAplicacion, 'No se permiten crear usuarios sin Cliente o Cuenta.' if c.new_record?

      c.active = Boolean row['Activo'] if row['Activo'].present?
      if row['Nombre'].present? && row['Apellido'].present?
        c.nombre = "#{row['Nombre'].split.map { |x| x.strip.capitalize }.join(' ')} #{row['Apellido'].split.map do |x|
          x.strip.capitalize
        end.join(' ')}"
      elsif row['Nombre'].present?
        c.nombre = row['Nombre'].split.map { |x| x.strip.capitalize }.join(' ')
      end
      c.legajo = row['Legajo'].to_s.split.map(&:strip).join(' ') if row['Legajo'].present?
      c.login = c.dni if c.new_record?
      if row['Contraseña'].present?
        c.password = row['Contraseña']
        c.password_confirmation = row['Contraseña']
      else
        c.password = c.dni
        c.password_confirmation = c.dni
      end
      c.save!
      @usuarios_count += 1
    end
  end
end
