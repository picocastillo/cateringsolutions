class ActsAsTaggableOn::Tag < ActiveRecord::Base # :nodoc: # rubocop:disable Rails/ApplicationRecord
  CARACTERES_VALIDOS = '\p{Alpha}[\p{Alnum}_]'.freeze
  FORMATO_MATCHEO = /\B#(#{CARACTERES_VALIDOS}+?)\b/
  FORMATO_VALIDO = /^#{CARACTERES_VALIDOS}+$/

  def self.[](name)
    find_by name: name
  end

  def self.de_modulo(modulo)
    Tag.joins(:taggings).where { taggings.taggable_type.start_with(my { modulo }) }.group(:id).order(:name)
  end

  def self.no_de_modulo(modulo)
    inicio = "#{modulo}%"
    Tag.joins(:taggings).where { taggings.taggable_type.not_like(my { inicio }) }.group(:id).order(:name)
  end
end
