module TurbolinksCacheControl
  extend ActiveSupport::Concern

  included do
    before_action :disable_turbolinks_cache, except: [:index, :show]
    before_action :enable_turbolinks_cache, only: [:index, :show]
  end

  private

  def enable_turbolinks_cache
    @turbolinks_cache_control = 'cache'
  end

  def disable_turbolinks_cache
    @turbolinks_cache_control = 'no-cache'
  end

  def disable_turbolinks_preview_cache
    @turbolinks_cache_control = 'no-preview'
  end
end
