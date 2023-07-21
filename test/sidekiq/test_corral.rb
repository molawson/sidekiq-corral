# frozen_string_literal: true

require "test_helper"
require_relative "../support/middleware_setup"
require_relative "../support/dummy_jobs"

module Sidekiq
  class TestCorral < Minitest::Test
    def test_that_version_number
      refute_nil ::Sidekiq::Corral::VERSION
    end

    def test_confine_changes_corral_in_block
      assert_nil(Corral.current)
      Corral.confine("inner_corral") { assert_equal("inner_corral", Corral.current) }
      assert_nil(Corral.current)
    end

    def test_confine_resets_to_original_value
      Corral.confine("outer_corral") do
        assert_equal("outer_corral", Corral.current)
        Corral.confine("inner_corral") { assert_equal("inner_corral", Corral.current) }
        assert_equal("outer_corral", Corral.current)
      end
    end

    def test_confine_resets_value_on_error
      Corral.confine("outer_corral") do
        assert_equal("outer_corral", Corral.current)
        assert_raises(StandardError) do
          Corral.confine("inner_corral") do
            assert_equal("inner_corral", Corral.current)
            raise(StandardError, "job failure")
          end
        end
        assert_equal("outer_corral", Corral.current)
      end
    end

    class ClientTest < Minitest::Test
      include MiddlewareSetup

      def setup
        Corral.install
      end

      def teardown
        Sidekiq::Job.clear_all
        uninstall_middleware
      end

      def test_updating_queue_and_job_corral_with_current_corral
        Corral.confine("critical") { DummyJob.perform_async }

        assert_equal(1, DummyJob.jobs.size)
        job = DummyJob.jobs.first

        assert_equal("critical", job["corral"])
        assert_equal("critical", job["queue"])
      end

      def test_updating_queue_with_corral_in_job_payload
        DummyJob.set(corral: :critical).perform_async

        assert_equal(1, DummyJob.jobs.size)
        job = DummyJob.jobs.first

        assert_equal("critical", job["corral"])
        assert_equal("critical", job["queue"])
      end

      def test_no_corral
        DummyJob.perform_async

        assert_equal(1, DummyJob.jobs.size)
        job = DummyJob.jobs.first

        assert_nil(job["corral"])
        assert_equal("low", job["queue"])
      end

      def test_explicit_nil_corral
        DummyJob.set(corral: nil).perform_async

        assert_equal(1, DummyJob.jobs.size)
        job = DummyJob.jobs.first

        assert_nil(job["corral"])
        assert_equal("low", job["queue"])
      end

      def test_exempt_queue
        exempt_queue = DummySpecialJob.get_sidekiq_options["queue"].to_s
        reinstall_middleware(exempt_queue)

        DummySpecialJob.set(corral: :critical).perform_async

        assert_equal(1, DummySpecialJob.jobs.size)
        job = DummySpecialJob.jobs.first

        assert_equal("critical", job["corral"])
        assert_equal(exempt_queue, job["queue"])
      end

      def test_multiple_exempt_queues
        exempt_queue = DummySpecialJob.get_sidekiq_options["queue"].to_s
        reinstall_middleware(["extra_special", exempt_queue])

        DummySpecialJob.set(corral: :critical).perform_async

        assert_equal(1, DummySpecialJob.jobs.size)
        job = DummySpecialJob.jobs.first

        assert_equal("critical", job["corral"])
        assert_equal(exempt_queue, job["queue"])
      end
    end

    class ServerTest < Minitest::Test
      include MiddlewareSetup

      def setup
        Corral.install
        Sidekiq::Testing.server_middleware { |chain| chain.add(Sidekiq::Corral::Server) }
      end

      def teardown
        Sidekiq::Job.clear_all
        uninstall_middleware
      end

      def test_passing_corral_to_sub_job
        DummyJob.set(corral: :critical).perform_async

        assert_equal(1, DummyJob.jobs.size)
        DummyJob.drain

        assert_equal(1, DummySubJob.jobs.size)
        sub_job = DummySubJob.jobs.first

        assert_equal("critical", sub_job["queue"])
        assert_equal("critical", sub_job["corral"])
      end

      def test_passing_corral_through_exempt_queue_job
        exempt_queue = DummySpecialJob.get_sidekiq_options["queue"].to_s
        reinstall_middleware(exempt_queue)

        DummyJob.set(corral: :critical).perform_async

        assert_equal(1, DummyJob.jobs.size)
        DummyJob.drain

        assert_equal(1, DummySubJob.jobs.size)
        DummySubJob.clear

        assert_equal(1, DummySpecialJob.jobs.size)
        special_job = DummySpecialJob.jobs.first

        assert_equal(exempt_queue, special_job["queue"])
        assert_equal("critical", special_job["corral"])
        DummySpecialJob.drain

        assert_equal(1, DummySubJob.jobs.size)
        special_sub_job = DummySubJob.jobs.first

        assert_equal("critical", special_sub_job["queue"])
        assert_equal("critical", special_sub_job["corral"])
      end

      def test_no_corral
        DummyJob.perform_async

        assert_equal(1, DummyJob.jobs.size)
        job = DummyJob.jobs.first

        assert_equal(DummyJob.get_sidekiq_options["queue"].to_s, job["queue"])

        DummyJob.drain

        assert_equal(1, DummySpecialJob.jobs.size)
        special_job = DummySpecialJob.jobs.first

        assert_equal(DummySpecialJob.get_sidekiq_options["queue"].to_s, special_job["queue"])

        assert_equal(1, DummySubJob.jobs.size)
        sub_job = DummySubJob.jobs.first

        assert_equal(DummySubJob.get_sidekiq_options["queue"].to_s, sub_job["queue"])

        DummySubJob.drain
        DummySpecialJob.drain

        assert_equal(1, DummySubJob.jobs.size)
        special_sub_job = DummySubJob.jobs.first

        assert_equal(DummySubJob.get_sidekiq_options["queue"].to_s, special_sub_job["queue"])
      end
    end
  end
end
