require 'sidekiq/client'

module Sidekiq
  module BatchClient

    #
    # The Sidekiq Batch client adds atomicity to batch definition:
    # all jobs created within the +jobs+ block are pushed into a
    # temporary array and then all flushed at once to Redis in a single
    # transaction.  This solves two problems:
    #
    # 1. We don't "half-create" a batch due to a networking issue
    # 2. We don't have a "completed" race condition when creating the jobs slower
    #    than we can process them.
    #
    # NB: creating very large numbers of jobs in one atomic block can be
    # dangerous -- it can spike Redis latency.  I generally recommend creating
    # blocks of jobs in parallel, 10,000 jobs per block, by creating an initial
    # set of jobs in the batch which reopen the batch and push those blocks.
    # It's not unusual for customers to have batches with 100,000+ jobs.

    def flush(conn)
      return if collected_payloads.nil?

      collected_payloads.each do |payloads|
        atomic_push(conn, payloads)
      end
    end

    private

    def collected_payloads
      Thread.current[:sidekiq_batch_payloads]
    end

    def raw_push(payloads)
      if defining_batch?
        collected_payloads << payloads
        true
      else
        super
      end
    end

    def defining_batch?
      Thread.current[:sidekiq_batch_payloads]
    end
  end
end

Sidekiq::Client.prepend(Sidekiq::BatchClient)
