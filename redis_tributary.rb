require 'socket'
require 'redis'
require 'optparse'

require_relative './proxy_connection'
require_relative './vector_clock'
require_relative './redis_command_buffer'
require_relative './command_line'

class RedisProxyServer
  def initialize(
    node_count:,
    node_id:,
    tributary_args:,
    server_host: '0.0.0.0',
    server_port: 36379
  )
    @tributary_args = tributary_args
    @server_host = server_host
    @server_port = server_port
    @server = TCPServer.new(server_host, server_port)
    @clock = VectorClock.new(node_id.to_i, node_count.to_i)
  end

  def listen
    puts "Listening on #{@server_host}:#{@server_port}..."
    loop do
      Thread.start(@server.accept) do |client|
        puts 'Bound!'
        redis_client = RedisTributary.new(@tributary_args.merge(clock: @clock))
        connection = ProxyConnection.new(client)
        connection.proxy_to_downstream(redis_client.upstream)
        connection.readlines do |line|
          redis_client.proxy_to_upstream(line)
        end
      end
    end
  end
end

class RedisTributary
  def initialize(
    clock:,
    redis_host: '0.0.0.0',
    redis_port: 6379
  )
    @redis_host = redis_host
    @redis_port = redis_port
    @redis = Redis.new(host: redis_host, port: redis_port)
    @clock = clock
    @buffer = RedisCommandBuffer.new
  end

  def proxy_to_upstream(line)
    puts "Sending to upstream: '#{line.strip}'"
    @buffer.push(line)

    if @buffer.complete?
      puts "Received command: '#{@buffer.command}' with args: '#{@buffer.arguments}'"
      @clock.increment
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
server.listen
