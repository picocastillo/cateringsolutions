class Notify
  def self.exception(e, vars = {})
    text = vars.map { |var, value| "#{var} = #{value.inspect}" }.join("\n\n") << "\n" << e.formatted
    Rails.logger.error text
    return if Rails.env.development?

    ApplicationMailer.notificacion_excepcion("[Exception] #{e.class}: #{e.message}",
                                             text).deliver_later
  end
end
