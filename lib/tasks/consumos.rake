namespace :consumos do
  desc 'Enviar reporte mensual de consumos a administradores de empresa. Uso: rake consumos:reporte_mensual[cliente_id]'
  task :reporte_mensual, [:cliente_id] => :environment do |_t, args|
    clientes = if args[:cliente_id].present?
                 Clientes::Cliente.where(id: args[:cliente_id])
               else
                 Clientes::Cliente.active
               end

    enviados = 0
    errores = 0

    clientes.find_each do |cliente|
      next if cliente.limite_compra_pesos.blank? && cliente.limite_compra_dolares.blank?

      admins = cliente.usuarios
                      .select { |u| u.cumple_rol?(:administrador_empresa) && u.email_principal.present? }

      next if admins.empty?

      emails = admins.map(&:email_principal).uniq

      emails.each do |email|
        mail = ConsumosMailer.reporte_mensual(cliente, email)
        mail.deliver_now
        enviados += 1
        puts "Enviado reporte de #{cliente.nombre} a #{email}"
      rescue StandardError => e
        errores += 1
        puts "Error enviando a #{email} (#{cliente.nombre}): #{e.message}"
        Rails.logger.error "ConsumosMailer error for cliente #{cliente.id}: #{e.message}"
      end
    end

    puts "\nResumen: #{enviados} enviados, #{errores} errores"
  end
end
