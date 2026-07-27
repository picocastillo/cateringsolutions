Rails.application.config.session_store :active_record_store, key: '_kiosk_session', expire_after: 744.hours,
                                                             secure_session_only: true
