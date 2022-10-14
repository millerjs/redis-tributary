require 'socket'
require 'redis'

require_relative './proxy_connection'
require_relative './vector_clock'
require_relative './redis_command_buffer'

class RedisProxyServer
  def initialize(server_host: '127.0.0.1', server_port: 36379)
    @server_host = server_host
    @server_port = server_port
    @server = TCPServer.new(server_host, server_port)
  end

  def listen
    puts "Listening on localhost:#{@server_port}..."
    loop do
      Thread.start(@server.accept) do |client|
        redis_client = RedisTributary.new
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
  def initialize(redis_host: '127.0.0.1', redis_port: 6379)
    @redis_host = redis_host
    @redis_port = redis_port
    @redis = Redis.new(host: redis_host, port: redis_port)
    @clock = VectorClock.new(1, 3)
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

server = RedisProxyServer.new
server.listen
