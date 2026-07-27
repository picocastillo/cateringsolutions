module Clientes
  class ClientesParaAcQuery < ApplicationQuery
    attr_accessor :q, :user

    validates :q, presence: true, length: { minimum: 2 }

    def relation
      sq = Cliente.active.disponibles_en(user.tienda_activa).order(:nombre)

      if q.present?
        params = {}
        where_string = ''

        # Search by text (nombre, email)
        if (textos = q.to_s.upcase.tr('0-9', '').split.compact_blank).present?
          where_string = [
            where_string,
            textos.map.with_index { |_, i| "clientes.nombre like :texto_#{i}" }.join(' and '),
            textos.map.with_index { |_, i| "clientes.email like :texto_#{i}" }.join(' and ')
          ].compact_blank.join(' or ')
          textos.each.with_index { |t, i| params[:"texto_#{i}"] = "%#{t}%" }
        end

        # Search by numbers (CUIT)
        if (numeros = q.to_s.tr('A-Z', '').split.compact_blank).present?
          where_string = [
            where_string,
            numeros.map.with_index { |_, i| "clientes.cuit like :nro_#{i}" }.join(' and ')
          ].compact_blank.join(' or ')
          numeros.each.with_index { |t, i| params[:"nro_#{i}"] = "%#{t}%" }
        end

        sq = sq.where where_string, params if where_string.present?
      end

      sq
    end
  end
end
