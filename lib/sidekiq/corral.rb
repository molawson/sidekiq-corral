# frozen_string_literal: true

require "sidekiq"

require_relative "corral/version"

module Sidekiq
  module Corral
    class Error < StandardError
    end

    def self.current
      Thread.current[:sidekiq_corral_queue]
    end

    def self.current=(queue)
      Thread.current[:sidekiq_corral_queue] = queue
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

      def call(_worker, job, _queue)
        Corral.current = job["corral"] if job["corral"]
        yield
      ensure
        Corral.current = nil
      end
    end
  end
end
