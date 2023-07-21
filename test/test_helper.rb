# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "sidekiq/corral"

require "minitest/autorun"
require "minitest/color"
require "sidekiq/testing"
