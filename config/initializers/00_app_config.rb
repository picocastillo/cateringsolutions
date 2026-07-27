env_config = Rails.root.join("config/app/#{Rails.env}.yml").to_s
AppConfig = ConfigSpartan.create do
  file Rails.root.join('config/app/base.yml').to_s
  file env_config if File.exist? env_config
end
