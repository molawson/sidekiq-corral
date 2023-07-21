# frozen_string_literal: true

require "sidekiq"

require_relative "corral/version"

module Sidekiq
  module Corral
    class Error < StandardError
    end

    class << self
      def confine(queue)
        orig_queue = current
        self.current = queue
        yield
      ensure
        self.current = orig_queue
      end

      def current
        Thread.current[:sidekiq_corral_queue]
      end

      def install(exempt_queues = [])
        Sidekiq.configure_client do |config|
          config.client_middleware { |chain| chain.add(Sidekiq::Corral::Client, exempt_queues) }
        end

        Sidekiq.configure_server do |config|
          config.server_middleware { |chain| chain.add(Sidekiq::Corral::Server) }
          config.client_middleware { |chain| chain.add(Sidekiq::Corral::Client, exempt_queues) }
        end
      end

      private

      def current=(queue)
        Thread.current[:sidekiq_corral_queue] = queue
      end
    end

    class Client
      include Sidekiq::ClientMiddleware

      def initialize(exempt_queues = [])
        @exempt_queues = Array(exempt_queues).map(&:to_s)
      end

      def call(_worker_class, job, _queue, _redis_pool)
        job["corral"] = Corral.current if Corral.current
        job["queue"] = job["corral"] if job["corral"] && !@exempt_queues.include?(job["queue"])
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
