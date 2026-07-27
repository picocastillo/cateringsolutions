# Rails 5 usa x defecto :en para pluralizar los nombres de tabla, pero en el helper usa
# i18n.default_locale (es-AR), por eso ahora cargo las inflections en ambos locales
[:en, :'es-AR'].each do |locale|
  ActiveSupport::Inflector.inflections locale do |inflect|
    inflect.plural(/([rlnd])([A-Z]|_| |$)/, '\1es\2')
    inflect.plural(/([aeiou])([A-Z]|_| |$)/, '\1s\2')
    inflect.plural(/([aeiou])([A-Z]|_| )(.*[rlnd]$)/, '\1s\2\3es')
    inflect.plural(/([rlnd])([A-Z]|_| )(.*[aeiou]$)/, '\1es\2\3s')

    inflect.singular(/([aeiou])s([A-Z]|_| |$)/, '\1\2')
    inflect.singular(/([rlnd])es([A-Z]|_| |$)/, '\1\2')
    inflect.singular(/([aeiou])s([A-Z]|_| )(.*[rlnd])es$/, '\1\2\3')
    inflect.singular(/([rlnd])es([A-Z]|_| )(.*[aeiou])s$/, '\1\2\3')
    inflect.singular(/([rlnd])es([A-Z]|_| )(.*[rlnd])es$/, '\1\2\3')

    inflect.uncountable ['inicio', 'condicion_ganancias']

    ['user', 'account', 'password', 'session', 'item', 'tag', 'tagging'].each do |word|
      inflect.irregular word, "#{word}s"
    end
    inflect.irregular 'settings', 'settings'
    inflect.irregular 'mes', 'meses'
    inflect.human 'codigo', 'Código'
    inflect.human 'created_at', 'Fecha de alta'
    inflect.human 'discontinued_at', 'Fecha de baja'
    inflect.human 'telefono', 'Teléfono'
    inflect.human 'active', 'Activo'
    inflect.human 'progress', 'Progreso'
    inflect.human 'finished_in', 'Terminó En'
  end
end

# En Rails 4 cambiaron el apply_inflections asi que tipo_comprobante (y otros) q se pluraliza a
# tipos_comprobantes ahora pasaron a quedar como tipos_comprobante. Lo cual quizas no está mal,
# pero habria q renombrar todas las tablas, o agregar los irregular. Revisar al final
module ActiveSupport
  module Inflector
    def apply_inflections(word, rules, locale = :en)
      result = word.to_s.dup

      unless word.empty? || inflections(locale).uncountables.any? { |inflection| result =~ /\b#{inflection}\Z/i }
        rules.each { |(rule, replacement)| break if result.gsub!(rule, replacement) }
      end
      result
    end
  end
end
