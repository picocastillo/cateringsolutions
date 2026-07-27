module Infraestructura
  module Taggable
    extend ActiveSupport::Concern

    module ClassMethods
      def taggable(*)
        acts_as_taggable_on(*)
      end
    end

    included do
      validate :tags_validos
    end

    def has_tag?(tag_name)
      tag_list.include? tag_name
    end

    private

    def tags_validos
      tags_invalidos = tag_types.flat_map { |tt| send("#{tt.to_s.singularize}_list") }.reject { |tag| tag_valido? tag }
      return unless tags_invalidos.any?

      errors.add :base,
                 'Los siguientes tags tienen formato inválido: ' \
                 "#{tags_invalidos.join(', ')}. Solo pueden tener letras, números, " \
                 'guiones bajos y hasta 50 characteres'
    end

    def tag_valido?(tag)
      tag.strip =~ ActsAsTaggableOn::Tag::FORMATO_VALIDO && tag.size < 51
    end
  end
end
