class ApplicationMailer < ActionMailer::Base
  default from: 'from@example.com'
  layout 'mailer'

  def notificacion_excepcion(subject, body)
    mail(to: 'sebachavarini@gmail.com', subject: subject, body: body)
  end
end
