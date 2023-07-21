# frozen_string_literal: true

module MiddlewareSetup
  def uninstall_middleware
    Sidekiq.configure_client do |config|
      config.client_middleware { |chain| chain.remove(Sidekiq::Corral::Client) }
    end

    Sidekiq.configure_server do |config|
      config.server_middleware { |chain| chain.add(Sidekiq::Corral::Server) }
      config.client_middleware { |chain| chain.add(Sidekiq::Corral::Client) }
    end
  end

  def reinstall_middleware(opts = {})
    uninstall_middleware
    install_middleware(opts)
  end

  def install_middleware(opts = {})
    Sidekiq::Corral.install(opts)
  end
end
