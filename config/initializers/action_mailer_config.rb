ActionMailer::Base.smtp_settings = {
  enable_starttls_auto: true,
  address: 'smtp.gmail.com',
  domain: 'cateringsolutions.com.ar',
  port: 587,
  authentication: 'plain',
  user_name: 'kiosksters@gmail.com',
  password: 'cqltjuwtiicmjvbx'
}

# Para que los links salgan con el link correcto
ActionMailer::Base.default_url_options = {
  host: Rails.configuration.action_mailer.asset_host.sub(%r{^https?://}, ''),
  protocol: Rails.configuration.action_mailer.asset_host[/^https?/, 0]
}

class SandboxEmailInterceptor
  def self.delivering_email(message)
    # Modifico el subject para saber que es un mail de prueba
    message.subject.prepend '[TEST] '

    white_list = (['sebachavarini@gmail.com'] if Rails.env.development?)

    destinatarios_existentes = [:to, :cc, :bcc].any? { |field| message.send(field).present? }

    # Sólo permito mandarlo a ciertas direcciones para que no salga sin querer a andreani, oca, y demás
    [:to, :cc, :bcc].each do |field|
      next if message.send(field).blank?

      message.send("#{field}=", message.send(field).select do |address|
        white_list.include? address
      end)
    end

    # Cancelo envío si no tiene destinatarios
    return unless destinatarios_existentes && [:to, :cc, :bcc].all? { |field| message.send(field).blank? }

    Rails.logger.info 'Error: mensaje sin destinatarios válidos. Envio del email CANCELADO.'
    message.perform_deliveries = false
  end
end

ActionMailer::Base.register_interceptor(SandboxEmailInterceptor) if Rails.env.development? || Rails.env.staging?
