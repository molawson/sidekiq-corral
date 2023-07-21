# frozen_string_literal: true

require "test_helper"

module Sidekiq
  class TestCorral < Minitest::Test
    class DummyWorker
      def perform(one_id, another_id, message)
      end
    end

    def teardown
      Corral.current = nil
    end

    def test_that_version_number
      refute_nil ::Sidekiq::Corral::VERSION
    end

    def test_current
      assert_nil(Corral.current)
      Corral.current = "my_corral"
      assert_equal("my_corral", Corral.current)
    end
  end
end
