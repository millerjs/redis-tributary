require 'socket'
require 'redis'

require_relative './proxy_connection'
require_relative './vector_clock'

class RedisProxyServer
  def initialize(port = 36379)
    @port = port
    @server = TCPServer.new port
  end

  def listen
    puts "Listening on #{@port}..."
    loop do
      Thread.start(@server.accept) do |client|
        redis_client = RawRedisClient.new
        connection = ProxyConnection.new(client)
        connection.proxy_to_downstream(redis_client.upstream)
        connection.readlines do |line|
          redis_client.proxy_to_upstream(line)
        end
      end
    end
  end
end

class RawRedisClient
  def initialize(host: 'localhost', port: 6379)
    @host = host
    @port = port
  end

  def proxy_to_upstream(line)
    puts "Sending to upstream: '#{line.strip}'"
    upstream.puts(line)
  end

  def upstream
    @upstream ||= TCPSocket.new(@host, @port)
  end
end

server = RedisProxyServer.new
server.listen
