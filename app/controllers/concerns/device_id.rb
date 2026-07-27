module DeviceId
  def client_app
    case request.headers['User-Agent']
    when 'DocHouse for Android' then 'android'
    when 'DocHouse for iOS' then 'ios'
    else 'web'
    end
  end
end
