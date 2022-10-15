# frozen_string_literal: true

require 'socket'
require 'redis'
require 'optparse'
require 'json'

require_relative './proxy_connection'
require_relative './vector_clock'
require_relative './redis_command_buffer'
require_relative './command_line'
require_relative './broadcast_queue'

class RedisProxyServer
  def initialize(
    node_count:,
    node_id:,
    tributary_args:,
    tributary_hosts:,
    tributary_ports:,
    server_host: '0.0.0.0',
    server_port: 36379
  )
    @tributary_hosts = tributary_hosts
    @tributary_ports = tributary_ports
    @tributary_args = tributary_args
    @server_host = server_host
    @server_port = server_port
    @server = TCPServer.new(server_host, server_port)
    @node_id = node_id.to_i
    @node_count = node_count.to_i
    @clock = VectorClock.new(@node_id, @node_count)
  end

  def listen_redis_clients
    puts "Listening for redis connections on #{@server_host}:#{@server_port}..."
    loop do
      Thread.start(@server.accept) do |client|
        puts 'Bound to new redis client!'

        redis_client = RedisTributary.new(@tributary_args.merge(
          clock: @clock,
          node_count: @node_count,
          node_id: @node_id
        ))

        connection = ProxyConnection.new(client)
        connection.proxy_to_downstream(redis_client.upstream)
        connection.readlines do |line|
          redis_client.proxy_to_upstream(line)
        end
      end
    end
  end

  def listen_for_broadcasts
    host, port = [@tributary_hosts[@node_id], @tributary_ports[@node_id]]
    broadcast_server = TCPServer.new(host, port)

    redis = Redis.new(
      host: @tributary_args[:redis_host],
      port: @tributary_args[:redis_port]
    )

    Thread.new do
      puts "Listening for tributary connections on #{@host}:#{@port}..."
      loop do
        client = broadcast_server.accept
        puts 'Bound to new broadcast client!'

        value = JSON.parse(client.gets)
        puts "Received: #{value}"
        command, *args = value['message']
        redis.public_send(command, *args)
      end
    end
  end

  def broadcast
    Thread.new do
      puts "Connecting to broadcast queue: #{@tributary_args.slice(:redis_host, :redis_port)}"

      redis = Redis.new(
        host: @tributary_args[:redis_host],
        port: @tributary_args[:redis_port]
      )
      queue = BroadcastQueue.new(redis, @node_id, @node_count)

      while (value = queue.claim)
        id = value['id'].to_i
        begin
          puts "Broadcast: #{value} to node #{id} at #{@tributary_hosts[id]}:#{@tributary_ports[id]}"
          socket = TCPSocket.new(@tributary_hosts[id], @tributary_ports[id])
          socket.puts(JSON.dump(value))
          queue.complete
        rescue StandardError => e
          puts "Error: #{e}"
          queue.unclaim
          sleep(1)
        end
      end
    end
  end
end

class RedisTributary
  def initialize(
    clock:,
    node_id:,
    node_count:,
    redis_host: '0.0.0.0',
    redis_port: 6379
  )
    @redis_host = redis_host
    @redis_port = redis_port
    @redis = Redis.new(host: redis_host, port: redis_port)
    @clock = clock
    @buffer = RedisCommandBuffer.new
    @broadcast_queue = BroadcastQueue.new(@redis, node_id, node_count)
  end

  def proxy_to_upstream(line)
    puts "Sending to upstream: '#{line.strip}'"
    @buffer.push(line)

    if @buffer.complete?
      puts "Received command: '#{@buffer.command}' with args: '#{@buffer.arguments}'"
      @clock.increment
      @broadcast_queue.push(@clock.timestamps, @buffer.to_a)
      puts "Current clock: #{@clock.timestamps}\n\n"
    end

    upstream.puts(line)
  end

  def upstream
    @upstream ||= TCPSocket.new(@redis_host, @redis_port)
  end
end

$stdout.sync = true

server = RedisProxyServer.new(parse_args)
server.broadcast
server.listen_for_broadcasts
server.listen_redis_clients
