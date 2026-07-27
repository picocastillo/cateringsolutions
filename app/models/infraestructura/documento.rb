module Infraestructura
  class Documento < ApplicationRecord
    acts_as_list scope: :documentable
    belongs_to :documentable, polymorphic: true, optional: true
    belongs_to :autor, class_name: 'Usuarios::Usuario'

    has_attached_file :documento, styles: lambda { |a|
      if ['image/jpeg', 'image/png', 'image/gif', 'image/svg'].include?(a.content_type)
        { thumb: ['x220>', :webp], medium: ['x420>', :webp],
          hd: ['x720>', :webp], original: 'x720>' }
      else
        {}
      end
    }, url: '/system/documentos/:id_partition/:basename-:style.:extension',
                                  processors: [:thumbnail]

    validates_attachment :documento, size: { less_than: 10.megabytes }
    do_not_validate_attachment_file_type :documento

    before_post_process :image?

    delegate :url, :path, :present?, :exists?, to: :documento, allow_nil: true

    def image?
      !!(documento_content_type =~ /^image.*/)
    end

    def to_s
      documento_file_name
    end
  end
end
