require 'rails'

module React
  module Router
    module Rails
      def self.get_asset_content(asset_name)
        if ::Rails.application.config.assets.compile
          ::Rails.application.assets[asset_name].to_s
        else
          manifest = ::Rails.application.assets_manifest
          # Find the corresponding compiled file:
          asset_path = manifest.assets[asset_name] || raise("No compiled asset for #{asset_name}, was it precompiled?")
          asset_full_path = ::Rails.root.join("public", manifest.directory, asset_path)
          File.read(asset_full_path)
        end
      end
      
      class Railtie < ::Rails::Railtie
        config.react_router = ActiveSupport::OrderedOptions.new

        config.react_router.max_renderers = 10
        config.react_router.timeout = 20 # seconds
        config.react_router.react_js = lambda { React::Router::Rails.get_asset_content('react.js') }
        config.react_router.react_server_js = lambda { React::Router::Rails.get_asset_content('react-server.js') }
        config.react_router.react_router_js = lambda { React::Router::Rails.get_asset_content('react_router.js') }
        config.react_router.route_filenames = ['components.js']

        # Include the react-router-rails view helper lazily
        initializer "react_router_rails.setup_view_helpers", group: :all do |app|
          ActiveSupport.on_load(:action_view) do
            include ::React::Router::Rails::ViewHelper
          end
        end

        config.after_initialize do |app|
          app.config.react_router.routes_js = lambda {
            app.config.react_router.route_filenames.map do |filename|
              app.assets[filename].to_s
            end.join(";")
          }

          do_setup = lambda do
            cfg = app.config.react_router
            React::Router::Renderer.setup!(cfg.react_js, cfg.react_server_js, cfg.react_router_js, cfg.routes_js,
                                           {:size => cfg.max_renderers, :timeout => cfg.timeout})
          end

          do_setup.call

          ActiveSupport::Reloader.to_prepare(&do_setup)
        end
      end
    end
  end
end
