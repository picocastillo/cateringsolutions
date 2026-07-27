# Load acts_as_taggable_on extensions after ApplicationRecord is available
Rails.application.config.after_initialize do
  require Rails.root.join('lib/extensions/acts_as_taggable_on_extensions')
end
