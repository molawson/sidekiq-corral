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

  def reinstall_middleware(exempt_queues = [])
    uninstall_middleware
    install_middleware(exempt_queues)
  end

  def install_middleware(exempt_queues = [])
    Sidekiq::Corral.install(exempt_queues)
  end
end
