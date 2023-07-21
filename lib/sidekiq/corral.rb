# frozen_string_literal: true

require "sidekiq"

require_relative "corral/version"

module Sidekiq
  module Corral
    class Error < StandardError
    end

    def self.confine(queue)
      orig_queue = current
      self.current = queue
      yield
    ensure
      self.current = orig_queue
    end

    def self.current
      Thread.current[:sidekiq_corral_queue]
    end

    def self.current=(queue)
      Thread.current[:sidekiq_corral_queue] = queue
    end

    def self.install
      Sidekiq.configure_client do |config|
        config.client_middleware { |chain| chain.add(Sidekiq::Corral::Client) }
      end

      Sidekiq.configure_server do |config|
        config.server_middleware { |chain| chain.add(Sidekiq::Corral::Server) }
        config.client_middleware { |chain| chain.add(Sidekiq::Corral::Client) }
      end
    end

    class Client
      include Sidekiq::ClientMiddleware

      def call(_worker_class, job, _queue, _redis_pool)
        job["corral"] = Corral.current if Corral.current
        job["queue"] = job["corral"] if job["corral"]
        yield
      end
    end

    class Server
      include Sidekiq::ServerMiddleware

      def call(_worker, job, _queue, &block)
        job["corral"] ? Corral.confine(job["corral"], &block) : block.call
      end
    end
  end
end
