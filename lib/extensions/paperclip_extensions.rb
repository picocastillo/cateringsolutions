class Paperclip::Attachment
  def rename_to(new_name)
    instance_write :file_name, new_name
  end

  # Seguro Paperclip debe tener alguna forma más elegante de acceder al archivo subido y luego renombrarlo
  def uploaded_file
    instance_eval { @queued_for_write[:original] }
  end
end

Paperclip::Attachment.default_options[:hash_secret] = 'CualquierA'
Paperclip::Attachment.default_options[:hash_data] = ':id/:created_at'

require 'paperclip/media_type_spoof_detector'
module Paperclip
  class MediaTypeSpoofDetector
    def spoofed?
      false
    end
  end
end
