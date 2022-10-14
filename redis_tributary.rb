require 'socket'
require 'redis'

class Server
  def initialize(port = 36379)
    @port = port
    @server = TCPServer.new port
  end

  def listen
    puts "Listening on #{@port}..."
    loop do
      Thread.start(@server.accept) do |client|
        redis_client = RawRedisClient.new
        redis_client.connect
        connection = ProxyConnection.new(client)
        connection.proxy_to_downstream(redis_client.upstream)
        connection.readlines do |downstream, line|
          redis_client.proxy_to_upstream(downstream, line)
        end
      end
    end
  end
end

class ProxyConnection
  def initialize(client)
    puts 'Connect received.'
    @client = client
  end

  def readlines(&block)
    while (line = @client.gets)
      puts "received: #{line}"
      yield(@client, line)
    end
  end

  def proxy_to_downstream(upstream)
    Thread.new do
      while (response = upstream.gets)
        @client.puts(response)
      end
    end
  end
end

class RawRedisClient
  attr_reader :upstream

  def initialize(host: 'localhost', port: 6379)
    @host = host
    @port = port
    @upstream = nil
  end

  def connect
    @upstream = TCPSocket.new @host, @port
    puts "\nConnected to upstream on port #{@host}:#{@port}"
  end

  def proxy_to_upstream(downstream, line)
    puts "\nSending to upstream: '#{line}'"
    @upstream.puts(line)
  end
end

server = Server.new
server.listen
