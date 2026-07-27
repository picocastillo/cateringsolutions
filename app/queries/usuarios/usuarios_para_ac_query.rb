module Usuarios
  class UsuariosParaAcQuery < ApplicationQuery
    attr_accessor :q, :user

    validates :q, presence: true, length: { minimum: 3 }

    def relation
      sq = if user.cliente?
             user.es_administrador_de_empresa? ? Usuario.active.where(cuenta_id: user.cliente.cuentas.map(&:id)) : Usuario.active.where(id: user)
           else
             Usuario.active
           end
      sq = sq.order(:nombre).where(tienda_cliente_id: user.tienda_activa.id).where.not(cuenta_id: nil)
      if q.present?
        params = {}
        where_string = ''
        if (textos = q.to_s.upcase.tr('0-9', '').split.compact_blank).present?
          where_string = [
            where_string, textos.map.with_index { |_, i| "usuarios.nombre like :texto_#{i}" }.join(' and ')
          ].compact_blank.join(' or ')
          textos.each.with_index { |t, i| params[:"texto_#{i}"] = "%#{t}%" }
        end
        if (numeros = q.to_s.upcase.tr('A-Z', '').split.compact_blank).present?
          where_string = [
            where_string, numeros.map.with_index { |_, i| "usuarios.legajo like :nro_#{i}" }.join(' and '),
            numeros.map.with_index { |_, i| "usuarios.dni like :nro_#{i}" }.join(' and ')
          ].compact_blank.join(' or ')
          numeros.each.with_index { |t, i| params[:"nro_#{i}"] = "%#{t}%" }
        end
        sq = sq.where where_string, params
      end
      sq
    end
  end
end
