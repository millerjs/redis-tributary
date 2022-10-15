# frozen_string_literal: true

class BroadcastQueue
  BROADCAST_QUEUE_NAME = 'redistributary:broadcast:queue'
  BROADCASTING_QUEUE_NAME = 'redistributary:broadcasting:queue'

  def initialize(redis, node_id, node_count)
    @redis = redis
    @node_id = node_id
    @node_count = node_count
  end

  def push(vector_timestamp, message)
    value = {
      ts: vector_timestamp.to_a,
      message: message
    }

    @redis.pipelined do |redis|
      @node_count.times.each do |i|
        next if i == @node_id
        puts "Pushing #{value} to queue for node #{i}"
        redis.rpush(BROADCAST_QUEUE_NAME, JSON.dump(value.merge(id: i)))
      end
    end
  end

  def claim
    value = @redis.brpoplpush(BROADCAST_QUEUE_NAME, BROADCASTING_QUEUE_NAME)
    deserialized = JSON.parse(value)
    puts "Read from broadcast queue: #{deserialized}"
    deserialized
  end

  def complete
    @redis.lpop(BROADCASTING_QUEUE_NAME)
  end

  def unclaim
    @redis.brpoplpush(BROADCASTING_QUEUE_NAME, BROADCAST_QUEUE_NAME)
  end
end
