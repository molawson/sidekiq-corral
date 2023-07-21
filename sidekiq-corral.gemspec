# frozen_string_literal: true

require_relative "lib/sidekiq/corral/version"

Gem::Specification.new do |spec|
  spec.name = "sidekiq-corral"
  spec.version = Sidekiq::Corral::VERSION
  spec.authors = ["Mo Lawson"]
  spec.email = ["mo@molawson.com"]

  spec.summary = "Confine a job and its child jobs to a single queue."
  spec.description = "Send a job to a queue and move all jobs it triggers to that same queue."
  spec.homepage = "https://github.com/molawson/sidekiq-corral"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 2.6.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .circleci appveyor Gemfile])
    end
  end
  spec.require_paths = ["lib"]

  # Uncomment to register a new dependency of your gem
  # spec.add_dependency "example-gem", "~> 1.0"
end
