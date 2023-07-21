# frozen_string_literal: true

class DummyJob
  include Sidekiq::Job

  sidekiq_options queue: :low

  def perform
    DummySubJob.perform_async
    DummySpecialJob.perform_async
  end
end

class DummySubJob
  include Sidekiq::Job

  sidekiq_options queue: :default

  def perform
  end
end

class DummySpecialJob
  include Sidekiq::Job

  sidekiq_options queue: :snowflake

  def perform
    DummySubJob.perform_async
  end
end
