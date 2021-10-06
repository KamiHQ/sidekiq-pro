require 'thread'

module Sidekiq
  # backup_limit controls the total number of pushes which will be enqueued
  # before the client will start throwing away jobs.  Note this limit is per-process.
  # Note also that a bulk push is considered one push but might contain 100s or 1000s
  # of jobs.
  options[:backup_limit] = 1_000

  # Reliable push is designed to handle transient network failures,
  # which cause the client to fail to deliver jobs to Redis.  It is not
  # designed to be a perfectly reliable client but rather an incremental
  # improvement over the existing client which will just fail in the face
  # of any networking error.
  #
  # Each client process has a local queue, used for storage if a network problem
  # is detected.  Jobs are pushed to that queue if normal delivery fails.  If
  # normal delivery succeeds, the local queue is drained of any stored jobs.
  #
  # The standard `Sidekiq::Client.push` API returns a JID if the push to redis succeeded
  # or raises an error if there was a problem.  With reliable push activated,
  # no Redis networking errors will be raised.
  #
  module ReliableClient
    @@local_queue = ::Queue.new

    at_exit do
      # last ditch effort to persist any jobs
      begin
        c = Sidekiq::Client.new
        c.drain unless c.local_queue.empty?
      rescue
        # did the best we could
      end
    end

    def local_queue
      @@local_queue
    end

    def raw_push(payloads)
      begin
        super
        if !local_queue.empty?
          ::Sidekiq.logger.info("[ReliablePush] Connectivity restored, draining local queue")
          drain
        end
      rescue Redis::BaseError => ex
        save_locally(payloads, ex)
      end
      true
    end

    def drain
      begin
        count = 0
        while !local_queue.empty?
          (pool, payloads) = local_queue.pop(true)
          oldpool, @redis_pool = @redis_pool, pool

          # WARNING: this skips past raw_push and any logic prepended with it:
          # the batch client, the testing client, etc.
          @redis_pool.with do |conn|
            conn.multi do
              atomic_push(conn, payloads)
            end
          end
          count += 1
          payloads = nil
        end
        Sidekiq::Pro.metrics.increment("jobs.recovered.push", by: count) if count > 0
      rescue Redis::BaseError => ex
        save_locally(payloads, ex) if payloads
      ensure
        @redis_pool = oldpool
      end
    end

    def save_locally(payloads, ex)
      sz = local_queue.size
      if sz > ::Sidekiq.options[:backup_limit]
        ::Sidekiq.logger.error("[ReliablePush] Reached job backup limit, discarding job due to #{ex.class}: #{ex.message}")
        false
      else
        ::Sidekiq.logger.warn("[ReliablePush] Enqueueing job locally due to #{ex.class}: #{ex.message}") if sz == 0
        local_queue << [@redis_pool, payloads]
        payloads
      end
    end
  end

  class Client
    def self.reliable_push!
      return false if Sidekiq::Client.new.is_a?(ReliableClient)

      ::Sidekiq.logger.debug("ReliablePush activated")
      Sidekiq::Client.prepend(ReliableClient)
      true
    end
  end
end
