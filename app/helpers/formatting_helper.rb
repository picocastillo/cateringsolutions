module FormattingHelper
  def percent(value, decimals = 1)
    number_to_percentage(value, precision: decimals) if value.present?
  end

  def percent_int(value)
    percent value, 0
  end

  def format_money(value, decimals: 2)
    case value
    when Danconia::Money
      value.format(decimals: decimals, format: '%u %n')
    else
      number_to_currency value, precision: decimals
    end
  end

  def decimal(number, decimals = 2)
    "%.#{decimals}f" % number if number
  end

  def graduacion(number)
    '%+.2f' % number if number
  end

  def angulo(number)
    "#{number}°" if number
  end

  def sino(bool)
    bool ? 'Si' : 'No'
  end

  def pedido_estado_label(objeto, cobrado_cliente = false)
    estado = objeto.estado
    estado = Pedidos::Estado[:confirmado] if current_user.cliente? && estado.id >= 3 && estado.id != 5
    content_tag :span, "#{estado}#{' y Pagado' if cobrado_cliente}",
                class: "label estado #{estado.to_sym.downcase}"
  end

  def active_label(objeto)
    estado = objeto.active? ? 'Activado' : 'Desactivado'
    content_tag :span, estado,
                class: "label estado #{estado.downcase}",
                data: { tooltip: estado }
  end

  def estado_label(objeto, abreviado = false)
    estado = objeto.estado
    content_tag :span, abreviado ? estado.to_s[0] : estado.to_s,
                class: "label estado #{estado.to_sym.downcase}",
                data: { tooltip: (estado.tip if estado.try(:tip)) }
  end
end
