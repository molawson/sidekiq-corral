# frozen_string_literal: true

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
  end
end
