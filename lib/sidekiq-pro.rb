# frozen_string_literal: true

require 'sidekiq'
require 'sidekiq/pro/version'
require 'sidekiq/pro/worker'
require 'sidekiq/pro/api'
require 'sidekiq/pro/push'
require 'sidekiq/pro/util'
require 'sidekiq/pro/metrics'
require 'sidekiq/batch'

Sidekiq.send(:remove_const, :LICENSE)
Sidekiq.send(:remove_const, :NAME)
Sidekiq::NAME = "Sidekiq Pro"
Sidekiq::LICENSE = "Sidekiq Pro #{Sidekiq::Pro::VERSION}, commercially licensed.  Thanks for your support!"

Sidekiq.configure_server do
  class Sidekiq::CLI
    def self.banner
      File.read(File.expand_path(File.join(__FILE__, '../sidekiq/intro.ans')))
    end
  end
  require 'sidekiq/pro/basic_fetch'
  Sidekiq.options[:fetch] = Sidekiq::Pro::BasicFetch
end


# Enable various reliability add-ons:
#
#   Sidekiq.configure_server do |config|
#     config.super_fetch!
#     config.reliable_scheduler!
#     # enable both
#     config.reliable!
#   end
#
module Sidekiq
  def self.super_fetch!
    require 'sidekiq/pro/super_fetch'
    Sidekiq.options[:fetch] = Sidekiq::Pro::SuperFetch
    Array(Sidekiq.options[:labels]) << 'reliable'
    nil
  end

  def self.reliable_fetch!
    Sidekiq.logger.error { "reliable_fetch! has been removed from Sidekiq Pro, use super_fetch! instead" }
    super_fetch!
  end

  def self.timed_fetch!(timeout = 3600)
    Sidekiq.logger.error { "timed_fetch! has been removed from Sidekiq Pro, use super_fetch! instead" }
    super_fetch!
  end

  def self.reliable_scheduler!
    require 'sidekiq/pro/scheduler'
    Sidekiq.options[:scheduled_enq] = Sidekiq::Scheduled::FastEnq
  end

  def self.reliable!
    super_fetch!
    reliable_scheduler!
  end

  def self.redis_pool
    # Slight tweak to allow sharding support
    Thread.current[:sidekiq_redis_pool] || (@redis ||= Sidekiq::RedisConnection.create)
  end
end
