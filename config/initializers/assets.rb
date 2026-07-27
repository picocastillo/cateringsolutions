# Be sure to restart your server when you modify this file.

# Version of your assets, change this if you want to expire all your assets.
Rails.application.config.assets.version = '1.0'

# Add additional assets to the asset load path.
# Rails.application.config.assets.paths << Emoji.images_path
# Add Yarn node_modules folder to the asset load path.
Rails.application.config.assets.paths << Rails.root.join('node_modules')

# Disable SassC CSS compressor globally.
# sassc-rails auto-registers :sass in ALL environments, but SassC 2.4 cannot
# parse modern CSS nesting (button&{}) used by Swiper v12.
Rails.application.config.assets.css_compressor = nil

# Precompile additional assets.
# application.js, application.css, and all non-JS/CSS in the app/assets
# folder are already added.
Rails.application.config.assets.precompile += ['adds_on.js', 'swiper.css', 'temas/claro.css', 'temas/public.css',
                                               'temas/sidebar_modern.css',
                                               'temas/adds_on.css', 'fonts/themify-icons.css', 'fonts/simple-line-icons.css', 'print/*.css']
