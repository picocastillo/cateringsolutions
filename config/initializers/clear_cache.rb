# Por si se cambia un menú o algo cacheado
if Rails.env.development?
  begin
    Rails.cache.clear
  rescue StandardError
    nil
  end
end
