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

    def test_install
      Corral.install
    end

    class ClientTest < Minitest::Test
      def setup
        @worker_class = DummyWorker
        @job = { "args" => [1, 2, "buckle my shoe"], "queue" => "low" }
        @redis_pool = "fake_redis_pool"
      end

      def teardown
        Corral.current = nil
      end

      def test_updating_queue_and_job_corral_with_current_corral
        assert_nil(@job["corral"])
        Corral.current = "critical"
        Sidekiq::Corral::Client
          .new
          .call(@worker_class, @job, @job["queue"], @redis_pool) { "next_step" }
        assert_equal("critical", @job["corral"])
        assert_equal("critical", @job["queue"])
      end

      def test_updating_queue_with_corral_in_job_payload
        @job["corral"] = "critical"
        assert_nil(Corral.current)
        Sidekiq::Corral::Client
          .new
          .call(@worker_class, @job, @job["queue"], @redis_pool) { "next_step" }
        assert_equal("critical", @job["queue"])
      end

      def test_no_corral
        assert_nil(Corral.current)
        Sidekiq::Corral::Client
          .new
          .call(@worker_class, @job, @job["queue"], @redis_pool) { "next_step" }
        assert_nil(@job["corral"])
        assert_equal("low", @job["queue"])
      end
    end

    class ServerTest < Minitest::Test
      def setup
        @worker_class = DummyWorker
        @job = { "args" => [1, 2, "buckle my shoe"], "queue" => "critical", "corral" => "critical" }
      end

      def test_setting_current_corral_during_execution
        Sidekiq::Corral::Server
          .new
          .call(@worker_class, @job, @job["queue"]) { assert_equal(@job["corral"], Corral.current) }
        assert_nil(Corral.current)
      end

      def test_clearing_current_corral_on_error
        assert_raises(StandardError) do
          Sidekiq::Corral::Server
            .new
            .call(@worker_class, @job, @job["queue"]) do
              assert_equal(@job["corral"], Corral.current)
              fail(StandardError, "job failure")
            end
        end
        assert_nil(Corral.current)
      end

      def test_no_corral
        @job.delete("corral")
        Sidekiq::Corral::Server
          .new
          .call(@worker_class, @job, @job["queue"]) { assert_nil(Corral.current) }
      end
    end
  end
end
