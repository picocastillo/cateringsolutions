class AddLoginImagesToTiendas < ActiveRecord::Migration[5.2]
  def up
    require 'open-uri'
    require 'tempfile'

    # Pexels free license images - confirmed IDs from pexels.com
    images = {
      1 => { # Catering Solutions - daily meals B2B / catering
        url: 'https://images.pexels.com/photos/34307855/pexels-photo-34307855.jpeg?auto=compress&cs=tinysrgb&w=1920&fit=max',
        filename: 'catering-bg.jpg'
      },
      2 => { # Healthy food / delicatessen
        url: 'https://images.pexels.com/photos/2894651/pexels-photo-2894651.jpeg?auto=compress&cs=tinysrgb&w=1920&fit=max',
        filename: 'healthy-food-bg.jpg'
      }
    }

    autor = Usuarios::Usuario.first
    unless autor
      say 'No users found, skipping login image seeding'
      return
    end

    images.each do |tienda_id, config|
      tienda = Tiendas::Tienda.find_by(id: tienda_id)
      unless tienda
        say "Tienda #{tienda_id} not found, skipping"
        next
      end

      if tienda.documentos.any?
        say "Tienda #{tienda.nombre} already has images, skipping"
        next
      end

      begin
        say "Downloading image for #{tienda.nombre}..."
        tempfile = Tempfile.new([config[:filename].sub('.jpg', ''), '.jpg'])
        tempfile.binmode
        tempfile.write(URI.open(config[:url]).read)
        tempfile.rewind

        doc = Infraestructura::Documento.new(
          documentable: tienda,
          autor: autor,
          position: 1
        )
        doc.documento = tempfile
        doc.documento_file_name = config[:filename]
        doc.documento_content_type = 'image/jpeg'
        doc.save!
        tempfile.close!

        say "  -> Added background image for #{tienda.nombre}"
      rescue StandardError => e
        say "  -> Could not add image for #{tienda.nombre}: #{e.message}"
      end
    end
  end

  def down
    # Only remove documents that match our filenames
    filenames = ['catering-bg.jpg', 'healthy-food-bg.jpg']
    Infraestructura::Documento
      .where(documentable_type: 'Tiendas::Tienda', documento_file_name: filenames)
      .destroy_all
  end
end
