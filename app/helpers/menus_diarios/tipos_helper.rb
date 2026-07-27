module MenusDiarios
  # Centralizes the visual identity (icon + color) of each MenuDiario tipo so
  # the pedidos panels, the calendar widget, and any future surface stay in
  # sync. The `mdi_class` is for HTML contexts; `emoji` is for plain-text
  # contexts like the FullCalendar event title.
  module TiposHelper
    TIPO_VISUALS = {
      menu_diario: { mdi_class: 'mdi mdi-silverware-fork-knife', color: '#f59e0b', emoji: '🍽️' },
      productos_diarios: { mdi_class: 'mdi mdi-star', color: '#8b5cf6', emoji: '⭐' }
    }.freeze
    DEFAULT_TIPO_VISUALS = TIPO_VISUALS[:menu_diario]

    # Lookup by a MenuDiario instance, a Symbol (`:menu_diario` /
    # `:productos_diarios`), a Tipo enum value, or a tipo_id integer.
    def menu_diario_tipo_visuals(arg)
      key = case arg
            when Symbol               then arg
            when MenusDiarios::Tipo   then arg.name.to_sym
            when Integer              then tipo_key_from_id(arg)
            else                           tipo_key_from_id(arg.tipo_id) if arg.respond_to?(:tipo_id)
            end
      TIPO_VISUALS[key] || DEFAULT_TIPO_VISUALS
    end

    # ArEnums classes don't expose ActiveRecord-style `find_by` — looking up
    # by id has to use `[:symbol]` accessors. Returning nil for unknown ids
    # keeps `menu_diario_tipo_visuals` safe to call with bad data.
    def tipo_key_from_id(id)
      return nil if id.nil?

      case id
      when MenusDiarios::Tipo[:menu_diario].id       then :menu_diario
      when MenusDiarios::Tipo[:productos_diarios].id then :productos_diarios
      end
    end

    def menu_diario_tipo_icon(arg, extra_class: 'mr-2')
      v = menu_diario_tipo_visuals(arg)
      content_tag(:i, '', class: "#{v[:mdi_class]} #{extra_class}".strip, style: "color: #{v[:color]};")
    end
  end
end
