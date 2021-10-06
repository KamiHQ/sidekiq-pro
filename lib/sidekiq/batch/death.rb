# frozen_string_literal: true

=begin

Sidekiq batches will "die" if they have a job which:
1. is lost or killed somehow.
2. runs out of retries and dies.

Dead batches will never fire their :success callback
without manual intervention.  Ideally their dead jobs
can be found in the dead set and manually fixed.

=end

class Sidekiq::Batch::Status
  def dead?
    Sidekiq::Batch.redis(bid) do |conn|
      conn.sismember("batch-died", bid)
    end
  end

  def dead_jobs
    Sidekiq::Batch.redis(bid) do |conn|
      conn.smembers("b-#{bid}-died")
    end
  end
end

class Sidekiq::Batch::DeadSet
  include Enumerable

  def size
    @_size ||= Sidekiq.redis do |conn|
      conn.scard("batch-died")
    end
  end

  def each
    bids = Sidekiq.redis do |conn|
      conn.smembers("batch-died")
    end

    bids.each do |bid|
      status = nil
      begin
        status = Sidekiq::Batch::Status.new(bid)
      rescue NoSuchBatch
        # TTL expired in Redis, an old reference that can be purged.
        Sidekiq::Batch.redis(bid) { |conn| conn.srem("batch-died", bid) }
      end
      yield status if status
    end
  end
end

# Death can happen in a client process too (e.g. Web UI) so we don't want to wrap this
# in configure_server.
if Sidekiq.respond_to?(:death_handlers)
  Sidekiq.death_handlers << ->(job, ex) do
    return unless job['bid']

    bid = job["bid"]

    dead, _ = Sidekiq::Batch.redis(bid) do |conn|
      conn.pipelined do |m|
        m.sadd("batch-died", bid)
        m.sadd("b-#{bid}-died", Sidekiq.dump_json(job))
        # extend expiry so the batch data will linger along with any dead jobs
        m.expire("b-#{bid}-died", Sidekiq::Batch::ONE_DAY * 180)
        m.expire("b-#{bid}", Sidekiq::Batch::ONE_DAY * 180)
      end
    end

    # fire off any batch.on(:death) callbacks
    if dead
      q = Sidekiq::Batch.redis(bid) { |c| c.hget("b-#{bid}", "cbq") }
      q ||= job["queue"]
      args = ["death", bid, q]

      Sidekiq::Client.push('class' => Sidekiq::Batch::Callback,
                       'queue' => q,
                       'args' => args)
    end
  end
end
