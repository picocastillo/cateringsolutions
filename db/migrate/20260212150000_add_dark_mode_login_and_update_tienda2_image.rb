class AddDarkModeLoginAndUpdateTienda2Image < ActiveRecord::Migration[5.2]
  def up
    # Add dark_mode_login column
    add_column :tiendas, :dark_mode_login, :boolean, default: false, null: false

    # Set dark mode for tienda 2 (Tivoglio - white logo needs dark card)
    Tiendas::Tienda.find_by(id: 2)&.update_column(:dark_mode_login, true)

    # Replace tienda 2 background image with a greenish nature/healthy image
    require 'open-uri'
    require 'tempfile'

    tienda = Tiendas::Tienda.find_by(id: 2)
    return unless tienda

    autor = Usuarios::Usuario.first
    return unless autor

    # Remove existing background images
    tienda.documentos.where(documento_file_name: 'healthy-food-bg.jpg').destroy_all

    begin
      # Pexels #1300972 - beautiful green herbs/basil close-up, very green and natural
      url = 'https://images.pexels.com/photos/1300972/pexels-photo-1300972.jpeg?auto=compress&cs=tinysrgb&w=1920&fit=max'
      say "Downloading new image for #{tienda.nombre}..."

      tempfile = Tempfile.new(['healthy-nature-bg', '.jpg'])
      tempfile.binmode
      tempfile.write(URI.open(url).read)
      tempfile.rewind

      doc = Infraestructura::Documento.new(
        documentable: tienda,
        autor: autor,
        position: 1
      )
      doc.documento = tempfile
      doc.documento_file_name = 'healthy-nature-bg.jpg'
      doc.documento_content_type = 'image/jpeg'
      doc.save!
      tempfile.close!

      say "  -> Updated background image for #{tienda.nombre}"
    rescue StandardError => e
      say "  -> Could not update image for #{tienda.nombre}: #{e.message}"
    end
  end

  def down
    remove_column :tiendas, :dark_mode_login

    # Restore original image
    Infraestructura::Documento
      .where(documentable_type: 'Tiendas::Tienda', documento_file_name: 'healthy-nature-bg.jpg')
      .destroy_all
  end
end
